import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/time_reservation_card.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/product_purchase_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/phone_number_entry.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/combined_providers.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';
import 'package:gravity_desktop_app/screens/add_group.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:gravity_desktop_app/utils/provider_utils.dart';
import 'package:intl/intl.dart';

enum TimeIncrement { hour, halfHour }

enum ScreenState { single, group }

class AddPlayerScreen extends ConsumerStatefulWidget {
  const AddPlayerScreen({super.key});

  @override
  ConsumerState<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends ConsumerState<AddPlayerScreen> {
  final formatter = NumberFormat.decimalPattern();
  final _formKey = GlobalKey<FormState>();
  ScreenState _screenState = ScreenState.single;

  TextEditingController nameController = TextEditingController();
  TextEditingController ageController = TextEditingController();
  List<TextEditingController> phoneControllers = [TextEditingController()];
  TextEditingController amountPaidController = TextEditingController();

  int hoursReserved = 0;
  int minutesReserved = 0;
  bool isOpenTime = false;
  int initialFee = 0;

  final Map<int, int> _productsCart = {}; // id -> quantity

  Player? _selectedPlayer; // exists if we chose an existing player

  bool _detailsReadOnly = false;
  bool _inEditMode = false;

  Future<void> _fillPlayerDetails(Player selection) async {
    final playerPhones = await ref
        .read(pastPlayersProvider.notifier)
        .getPhoneNumbers(selection.playerID);

    setState(() {
      _detailsReadOnly = true;

      _selectedPlayer = selection;
      nameController.text = selection.name;
      ageController.text = selection.age.toString();
      phoneControllers.clear();

      // player phones
      if (playerPhones.isEmpty) {
        phoneControllers.add(TextEditingController());
      } else {
        for (var phone in playerPhones) {
          phoneControllers.add(TextEditingController(text: phone.number));
        }
      }
    });
  }

  void _incrementTime(TimeIncrement increment, PricesProductsSubs data) {
    final Subscription? sub = _selectedPlayer?.subscriptionId != null
        ? data.allSubs.firstWhere(
            (s) => s.subscriptionId == _selectedPlayer!.subscriptionId,
            orElse: () => throw Exception('Subscription not found'),
          )
        : null;

    setState(() {
      if (!isOpenTime) {
        if (increment == TimeIncrement.hour) {
          if (sub != null) {
            if (sub.remainingMinutes <
                ((hoursReserved + 1) * 60 + minutesReserved + 60)) {
              MyMaterialBanner.showBanner(context,
                  message: 'Not enough remaining time in subscription',
                  type: MessageType.error,
                  durationInSeconds: 2);
              return;
            }
          }
          if (hoursReserved < 12) {
            hoursReserved++;
          }
        } else if (increment == TimeIncrement.halfHour) {
          final oldMinutes = minutesReserved;
          if (minutesReserved == 0) {
            minutesReserved = 30;
          } else if (minutesReserved == 30 && hoursReserved < 12) {
            hoursReserved++;
            minutesReserved = 0;
          }

          if (sub != null) {
            if (sub.remainingMinutes <
                (hoursReserved * 60 + minutesReserved + 60)) {
              MyMaterialBanner.showBanner(context,
                  message: 'Not enough remaining time in subscription',
                  type: MessageType.error,
                  durationInSeconds: 2);
              // Reset to old value if not enough time
              minutesReserved = oldMinutes;
              return;
            }
          }
        }
      }
    });

    _updateTotalFee(data.prices, data.allProducts);
  }

  void _updateTotalFee(Map<TimeSlice, int> prices, List<Product> allProducts) {
    setState(() {
      initialFee = _selectedPlayer?.subscriptionId == null
          ? calculatePreCheckInFee(
              hoursReserved: hoursReserved,
              minutesReserved: minutesReserved,
              timeExtendedMinutes: 0,
              prices: prices,
              isOpenTime: isOpenTime,
            )
          : 0;

      // add products cart total to initial fee
      for (var entry in _productsCart.entries) {
        final Product product = allProducts.firstWhere(
          (p) => p.id == entry.key,
        );

        initialFee += entry.value * product.price;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(pricesProductsSubsProvider).when(
          data: (data) {
            return Scaffold(
              appBar: const MyAppBar(),
              body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Page Title with toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _screenState == ScreenState.single
                              ? 'Add New Player'
                              : 'Add Group of Players',
                          style: AppTextStyles.pageTitleStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(width: 24),
                        ToggleButtons(
                          isSelected: [
                            _screenState == ScreenState.single,
                            _screenState == ScreenState.group,
                          ],
                          onPressed: (index) {
                            setState(() {
                              _screenState = index == 0
                                  ? ScreenState.single
                                  : ScreenState.group;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          selectedBorderColor: Colors.blue,
                          selectedColor: Colors.white,
                          fillColor: Colors.blue,
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text('Single'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text('Group'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Main content area
                    Expanded(
                      child: _screenState == ScreenState.single
                          ? _addSinglePlayer(data)
                          : AddGroup(data),
                    ),
                  ],
                ),
              ),
            );
          },
          error: (err, stack) => Scaffold(
            appBar: const MyAppBar(),
            body: Center(
              child: Text('Error loading prices: $err'),
            ),
          ),
          loading: () => Scaffold(
            appBar: const MyAppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
        );
  }

  Future<void> _handleCheckIn(Map<TimeSlice, int> prices) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final name = nameController.text;
    final age = int.parse(ageController.text);
    final phoneNumbers = phoneControllers
        .map((controller) => controller.text)
        .where((phone) => phone.isNotEmpty)
        .toList();

    final int totalMinutesReserved = hoursReserved * 60 + minutesReserved;

    await ref.read(currentPlayersProvider.notifier).checkInPlayer(
          existingPlayerID: _selectedPlayer?.playerID,
          name: name,
          age: age,
          timeReservedMinutes: totalMinutesReserved,
          isOpenTime: isOpenTime,
          totalFee: initialFee,
          amountPaid: _selectedPlayer?.subscriptionId == null
              ? int.parse(amountPaidController.text)
              : 0,
          phoneNumbers: phoneNumbers,
          subscriptionId: _selectedPlayer?.subscriptionId,
          productsBought: _productsCart.isNotEmpty ? _productsCart : const {},
        );
    refreshAllProviders(ref);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Player added successfully!'),
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    for (var controller in phoneControllers) {
      controller.dispose();
    }
    amountPaidController.dispose();
    super.dispose();
  }

  Widget _addSinglePlayer(PricesProductsSubs data) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Form(
        key: _formKey,
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.88, // Content will take 88% of screen width
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // left column for products card
                Expanded(
                  flex: 30,
                  child: Column(
                    children: [
                      _buildProductsCard(data.allProducts, data.prices),
                    ],
                  ),
                ),

                // middle column with scrollable content
                Expanded(
                  flex: 45,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Player details section
                        _buildPlayerDetailsCard(),

                        // Phone Numbers Section
                        PhoneNumberEntryCard(
                          title: 'Phone Numbers (optional)',
                          controllers: phoneControllers,
                          isDisabled: _detailsReadOnly,
                          disableListModification: _detailsReadOnly,
                          addOnPressed: () {
                            setState(() {
                              phoneControllers.add(TextEditingController());
                            });
                          },
                          removeOnPressed: (int index) {
                            setState(() {
                              if (phoneControllers.length > 1) {
                                phoneControllers[index].dispose();
                                phoneControllers.removeAt(index);
                              }
                            });
                          },
                          onReorder: (int oldIndex, int newIndex) {
                            setState(() {
                              final controller =
                                  phoneControllers.removeAt(oldIndex);
                              phoneControllers.insert(newIndex, controller);
                            });
                          },
                        ),

                        // Time Reservation Section
                        _buildTimeReservationCard(data)
                      ],
                    ),
                  ),
                ),

                // Right column with payment details and add player button
                const SizedBox(width: 24),
                Expanded(
                  flex: 35,
                  child: Column(
                    children: [
                      _buildPaymentCard(data.prices),
                      if (_selectedPlayer != null &&
                          _selectedPlayer!.subscriptionId != null)
                        _buildSubscriberCard()
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MyCard _buildPlayerDetailsCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Player Details',
            style:
                AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 16),
          // Name field with autocomplete
          Autocomplete<Player>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty || _inEditMode) {
                return const Iterable<Player>.empty();
              }
              return ref.watch(pastPlayersProvider).when(data: (pastPlayers) {
                final fuse = Fuzzy(
                  pastPlayers,
                  options: FuzzyOptions(
                    keys: [
                      WeightedKey(
                          name: 'name',
                          weight: 1.0,
                          getter: (Player player) => player.name)
                    ],
                    threshold: fuzzyThreshold,
                  ),
                );

                final results = fuse.search(textEditingValue.text);
                return results.map((result) => result.item);
              }, error: (err, stack) {
                log("Error fetching past players: $err, $stack");
                return const Iterable<Player>.empty();
              }, loading: () {
                return const Iterable<Player>.empty();
              });
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 250, maxWidth: 400),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);

                        final bool isHighlighted =
                            AutocompleteHighlightedOption.of(context) == index;
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Container(
                            color: isHighlighted
                                ? Theme.of(context).focusColor.withAlpha(18)
                                : null,
                            child: ListTile(
                              selected: isHighlighted,
                              selectedTileColor: Colors.black.withAlpha(25),
                              title: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  option.subscriptionId != null
                                      ? '${option.name} (${option.age}) - Subscription Active'
                                      : '${option.name} (${option.age})',
                                  style: AppTextStyles.regularTextStyle,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            displayStringForOption: (Player option) => option.name,
            onSelected: (Player selection) async {
              await _fillPlayerDetails(selection);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              return FocusTraversalOrder(
                order: const NumericFocusOrder(1.0),
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: _detailsReadOnly,
                  onFieldSubmitted: (value) => onFieldSubmitted(),
                  onChanged: (value) {
                    // if the user is typing and not selecting
                    if (_selectedPlayer == null || _inEditMode) {
                      nameController.text = value;
                    }
                  },
                  style: AppTextStyles.regularTextStyle,
                  decoration: InputDecoration(
                    filled: _detailsReadOnly,
                    fillColor: _detailsReadOnly
                        ? Colors.grey.shade200
                        : Colors.transparent,
                    labelText: _detailsReadOnly ? "Name (Locked)" : 'Name',
                    labelStyle: AppTextStyles.regularTextStyle,
                    hintText: 'Enter player name',
                    hintStyle: AppTextStyles.subtitleTextStyle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    suffixIcon: _selectedPlayer != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!_inEditMode)
                                IconButton(
                                    icon: const Icon(Icons.edit, size: 24),
                                    tooltip: 'Edit Player Details',
                                    onPressed: () {
                                      setState(() {
                                        _detailsReadOnly = false;
                                        _inEditMode = true;
                                      });
                                    }),
                              if (_inEditMode)
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    size: 24,
                                    color: Colors.green,
                                  ),
                                  tooltip: 'Save Changes',
                                  onPressed: () {
                                    log("Edit player details confirmed");
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setState(() {
                                      _inEditMode = false;
                                      _detailsReadOnly = true;

                                      // Update the player details
                                      ref
                                          .read(pastPlayersProvider.notifier)
                                          .editPlayer(
                                            playerID: _selectedPlayer!.playerID,
                                            name: nameController.text,
                                            age: int.parse(ageController.text),
                                            phones: phoneControllers
                                                .map((c) => c.text)
                                                .where(
                                                    (phone) => phone.isNotEmpty)
                                                .toList(),
                                          );
                                    });
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 24, color: Colors.red),
                                tooltip: _inEditMode
                                    ? 'Cancel Edit'
                                    : 'Clear Selected Player',
                                onPressed: () async {
                                  if (_inEditMode) {
                                    // Cancel edit mode
                                    setState(() => _inEditMode = false);
                                    // Refill the player details
                                    await _fillPlayerDetails(_selectedPlayer!);
                                  } else {
                                    controller.clear();
                                    setState(() {
                                      _detailsReadOnly = false;
                                      _selectedPlayer = null;
                                      nameController.clear();
                                      ageController.clear();
                                      phoneControllers.clear();
                                      phoneControllers
                                          .add(TextEditingController());
                                    });
                                  }
                                },
                              ),
                            ],
                          )
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Age
          FocusTraversalOrder(
            order: const NumericFocusOrder(2.0),
            child: TextFormField(
              controller: ageController,
              style: AppTextStyles.regularTextStyle,
              readOnly: _detailsReadOnly,
              decoration: InputDecoration(
                filled: _detailsReadOnly,
                fillColor: _detailsReadOnly
                    ? Colors.grey.shade200
                    : Colors.transparent,
                labelText: _detailsReadOnly ? "Age (Locked)" : 'Age',
                labelStyle: AppTextStyles.regularTextStyle,
                hintText: 'Enter player age',
                hintStyle: AppTextStyles.subtitleTextStyle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an age';
                }
                final age = int.tryParse(value);
                if (age == null || age < 0) {
                  return 'Please enter a valid age';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeReservationCard(PricesProductsSubs data) {
    final Subscription? sub = _selectedPlayer?.subscriptionId != null
        ? data.allSubs.firstWhere(
            (s) => s.subscriptionId == _selectedPlayer!.subscriptionId,
            orElse: () => throw Exception('Subscription not found'),
          )
        : null;
    return TimeReservationCard(
      title: "Time Reservation",
      time: Duration(hours: hoursReserved, minutes: minutesReserved),
      isOpenTime: isOpenTime,
      oneHourOnPressed: () {
        setState(() {
          _incrementTime(TimeIncrement.hour, data);
        });
      },
      halfHourOnPressed: () {
        setState(() {
          _incrementTime(TimeIncrement.halfHour, data);
        });
      },
      resetOnPressed: () {
        setState(() {
          hoursReserved = 0;
          minutesReserved = 0;
          isOpenTime = false;
        });
        _updateTotalFee(data.prices, data.allProducts);
      },
      isOpenTimeOnChanged: (value) {
        setState(() {
          isOpenTime = value ?? false;
          if (isOpenTime) {
            hoursReserved = 0;
            minutesReserved = 0;
          }
          _updateTotalFee(data.prices, data.allProducts);
        });
      },
      warningCondition: ((sub != null &&
              sub.remainingMinutes < (hoursReserved * 60 + minutesReserved) &&
              !isOpenTime) ||
          sub != null && isOpenTime),
      warningText: sub != null
          ? 'Warning: This player has only ${sub.remainingMinutes ~/ 60} hours and ${sub.remainingMinutes % 60} minutes remaining in their subscription.'
          : null,
    );
  }

  MyCard _buildPaymentCard(Map<TimeSlice, int> prices) {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Payment Summary',
            style:
                AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 32),

          // Fee summary display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Fee',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedPlayer?.subscriptionId != null
                      ? initialFee == 0
                          ? 'Subscription Active'
                          : 'Subscription - ${formatter.format(initialFee)} SYP'
                      : isOpenTime
                          ? initialFee == 0
                              ? 'Open Time'
                              : 'Open Time - ${formatter.format(initialFee)} SYP'
                          : '${formatter.format(initialFee)}  SYP',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: AppButtonStyles.primaryButton,
                onPressed: () {
                  setState(() {
                    amountPaidController.text = '$initialFee';
                  });
                },
                child: Text("Pay in Full",
                    style: AppTextStyles.primaryButtonTextStyle),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Input for amount paid on check-in
          FocusTraversalOrder(
            order: NumericFocusOrder(phoneControllers.length + 7.0),
            child: TextFormField(
              controller: amountPaidController,
              style: AppTextStyles.regularTextStyle,
              enabled:
                  _selectedPlayer?.subscriptionId == null || initialFee > 0,
              decoration: InputDecoration(
                  labelText:
                      _selectedPlayer?.subscriptionId != null && initialFee == 0
                          ? 'Subscription Active'
                          : 'Amount Paid on Check-in',
                  labelStyle: AppTextStyles.regularTextStyle,
                  hintText: 'Enter amount paid',
                  hintStyle: AppTextStyles.subtitleTextStyle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  prefixText: 'SYP   ',
                  prefixStyle: AppTextStyles.regularTextStyle
                      .copyWith(color: Colors.black)),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (_selectedPlayer?.subscriptionId != null) {
                  return null; // No validation needed for subscription
                }
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = int.tryParse(value);
                if (amount == null || amount < 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FocusTraversalOrder(
              order: NumericFocusOrder(phoneControllers.length + 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    // make sure time is not 0
                    (minutesReserved == 0 &&
                                hoursReserved == 0 &&
                                !isOpenTime) ||
                            _inEditMode
                        ? null
                        : () async => await _handleCheckIn(prices),
                child: const Text("Add Player"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  MyCard _buildSubscriberCard() {
    return ref.watch(subscriptionsProvider).when(
        data: (subs) {
          final sub = subs.firstWhere(
              (sub) => sub.subscriptionId == _selectedPlayer!.subscriptionId,
              orElse: () => throw ("Not a sub"));

          final double remainingHours = sub.remainingMinutes / 60;
          final remainingPayment = sub.totalFee - sub.amountPaid;

          return MyCard(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Subscription Details',
                style: AppTextStyles.sectionHeaderStyle
                    .copyWith(color: Colors.black),
              ),
              const SizedBox(height: 24),

              // Remaining Hours
              Row(
                children: [
                  Text(
                    "Remaining Hours",
                    style: AppTextStyles.regularTextStyle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.history,
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${remainingHours.toStringAsFixed(1)} hours",
                style: AppTextStyles.amountTextStyle.copyWith(
                  color: Colors.blue.shade800,
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 16),

              // Subscription Fee
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Subscription Fee",
                          style: AppTextStyles.regularTextStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${formatter.format(sub.totalFee)} SYP",
                          style: AppTextStyles.regularTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Paid", style: AppTextStyles.regularTextStyle),
                        const SizedBox(height: 4),
                        Text("${formatter.format(sub.amountPaid)} SYP",
                            style: AppTextStyles.regularTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: sub.amountPaid > 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            )),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Remaining Payment",
                          style: AppTextStyles.regularTextStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${formatter.format(remainingPayment)} SYP",
                          style: AppTextStyles.regularTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: remainingPayment > 0
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Additional spacing at bottom
              const SizedBox(height: 8),
            ],
          ));
        },
        error: (err, stack) => MyCard(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading subscription details',
                      style: AppTextStyles.regularTextStyle
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$err',
                      style: AppTextStyles.subtitleTextStyle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        loading: () => MyCard(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      "Loading Subscription Details...",
                      style: AppTextStyles.regularTextStyle,
                    ),
                  ],
                ),
              ),
            ));
  }

  MyCard _buildProductsCard(
      List<Product> allProducts, Map<TimeSlice, int> prices) {
    return MyCard(
      child: Column(
        children: [
          Text("Products", style: AppTextStyles.sectionHeaderStyle),
          allProducts.isEmpty
              ? Center(
                  heightFactor: 3,
                  child: Text(
                    'No products available for purchase.',
                    style: AppTextStyles.subtitleTextStyle,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: allProducts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = allProducts[index];
                    final quantityInCart = _productsCart[product.id] ?? 0;
                    return ProductListItem(
                      product: product,
                      quantity: quantityInCart,
                      onQuantityChanged: (newQuantity) {
                        // Ensure the new quantity is within valid bounds
                        if (newQuantity < 0 ||
                            newQuantity > product.effectiveStock) {
                          return;
                        }

                        setState(() {
                          if (newQuantity > 0) {
                            _productsCart[product.id] = newQuantity;
                          } else {
                            // Remove from cart if quantity becomes zero
                            _productsCart.remove(product.id);
                          }
                          // Recalculate total fee
                          _updateTotalFee(prices, allProducts);
                        });
                      },
                    );
                  },
                )
        ],
      ),
    );
  }
}
