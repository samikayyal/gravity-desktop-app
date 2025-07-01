import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:intl/intl.dart';

enum TimeIncrement { hour, halfHour }

class AddPlayerScreen extends ConsumerStatefulWidget {
  const AddPlayerScreen({super.key});

  @override
  ConsumerState<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends ConsumerState<AddPlayerScreen> {
  final formatter = NumberFormat.decimalPattern();
  final _formKey = GlobalKey<FormState>();

  TextEditingController nameController = TextEditingController();
  TextEditingController ageController = TextEditingController();
  List<TextEditingController> phoneControllers = [TextEditingController()];
  TextEditingController amountPaidController = TextEditingController();

  int hoursReserved = 0;
  int minutesReserved = 0;
  bool isOpenTime = false;
  int totalFee = 0;

  Player? _selectedPlayer; // exists if we chose an existing player

  bool _detailsReadOnly = false;
  bool _inEditMode = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fillPlayerDetails(Player selection) async {
    final db = ref.read(databaseProvider);
    final playerPhones = await db.getPhoneNumbers(selection.playerID);

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
          phoneControllers.add(TextEditingController(text: phone));
        }
      }
    });
  }

  void _incrementTime(TimeIncrement increment) {
    ref.watch(subscriptionsProvider).whenData((subs) {
      final Subscription? sub = _selectedPlayer?.subscriptionId != null
          ? subs.firstWhere(
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesProvider);
    return pricesAsync.when(
      data: (prices) {
        return Scaffold(
          appBar: const MyAppBar(),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Page Title
                const Text(
                  'Add New Player',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Main content area
                Expanded(
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Form(
                      key: _formKey,
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor:
                              0.75, // Content will take 75% of screen width
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column with scrollable content
                              Expanded(
                                flex: 3,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Player details section
                                      _buildPlayerDetailsCard(),

                                      // Phone Numbers Section
                                      _buildPhoneNumbersCard(),

                                      // Time Reservation Section
                                      _buildTimeReservationCard()
                                    ],
                                  ),
                                ),
                              ),

                              // Right column with payment details and add player button
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    _buildPaymentCard(prices),
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
                  ),
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

  void _handleCheckIn(Map<TimeSlice, int> prices, int initialFee) {
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

    ref.read(currentPlayersProvider.notifier).checkInPlayer(
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
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Player added successfully!'),
      ),
    );
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
              return ref.watch(pastPlayersProvider).when(
                  data: (pastPlayers) {
                    final fuse = Fuzzy(
                      pastPlayers,
                      options: FuzzyOptions(
                        keys: [
                          WeightedKey(
                              name: 'name',
                              weight: 1.0,
                              getter: (Player player) => player.name)
                        ],
                        threshold: 0.5,
                      ),
                    );

                    final results = fuse.search(textEditingValue.text);
                    return results.map((result) => result.item);
                  },
                  error: (err, stack) {
                    debugPrint("Error fetching past players: $err, $stack");
                    return const Iterable<Player>.empty();
                  },
                  loading: () => const Iterable<Player>.empty());
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
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              option.subscriptionId != null
                                  ? '${option.name} (${option.age}) - Subscription Active'
                                  : '${option.name} (${option.age})',
                              style: AppTextStyles.regularTextStyle,
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
                                    debugPrint("Edit player details confirmed");
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

  MyCard _buildPhoneNumbersCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone Numbers (optional)',
            style:
                AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < phoneControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: FocusTraversalOrder(
                      order: NumericFocusOrder(3.0 + i),
                      child: TextFormField(
                        controller: phoneControllers[i],
                        style: AppTextStyles.regularTextStyle,
                        readOnly: _detailsReadOnly,
                        decoration: InputDecoration(
                          filled: _detailsReadOnly,
                          fillColor: _detailsReadOnly
                              ? Colors.grey.shade200
                              : Colors.transparent,
                          labelText: _detailsReadOnly
                              ? "Phone Number (Locked)"
                              : 'Phone Number',
                          labelStyle: AppTextStyles.regularTextStyle,
                          hintText: 'Enter phone number',
                          hintStyle: AppTextStyles.subtitleTextStyle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final phone = value.trim();
                            if (phone.length != 10) {
                              return 'Please enter a valid phone number';
                            }
                            if (!phone.startsWith("09")) {
                              return 'Phone number must start with 09';
                            }
                            if (phone.contains(RegExp(r'\D'))) {
                              return 'Phone number must contain only digits';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  if (i == phoneControllers.length - 1) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.add, size: 28),
                        tooltip: 'Add phone number',
                        onPressed: () {
                          setState(() {
                            phoneControllers.add(TextEditingController());
                          });
                        },
                      ),
                    ),
                    if (phoneControllers.length > 1) const SizedBox(width: 8),
                    if (phoneControllers.length > 1)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: const Icon(Icons.remove, size: 28),
                          tooltip: 'Remove phone number',
                          onPressed: () {
                            setState(() {
                              phoneControllers.removeAt(i);
                            });
                          },
                        ),
                      ),
                  ]
                ],
              ),
            ),
        ],
      ),
    );
  }

  MyCard _buildTimeReservationCard() {
    final Subscription? sub = _selectedPlayer?.subscriptionId != null
        ? ref.watch(subscriptionsProvider).valueOrNull?.firstWhere(
              (s) => s.subscriptionId == _selectedPlayer!.subscriptionId,
              orElse: () => throw Exception('Subscription not found'),
            )
        : null;
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Reservation',
            style:
                AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
          ),
          const SizedBox(height: 24),

          // Reserved Time Display
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100.withAlpha(156),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                isOpenTime
                    ? 'Open Time'
                    : '$hoursReserved Hours $minutesReserved Minutes',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Time Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FocusTraversalOrder(
                order: NumericFocusOrder(phoneControllers.length + 3.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: Text(
                    "+1 Hour",
                    style: AppTextStyles.primaryButtonTextStyle
                        .copyWith(fontSize: 18),
                  ),
                  onPressed: () {
                    setState(() {
                      _incrementTime(TimeIncrement.hour);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              FocusTraversalOrder(
                order: NumericFocusOrder(phoneControllers.length + 4.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: Text(
                    "+30 Minutes",
                    style: AppTextStyles.primaryButtonTextStyle
                        .copyWith(fontSize: 18),
                  ),
                  onPressed: () {
                    setState(() {
                      _incrementTime(TimeIncrement.halfHour);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              FocusTraversalOrder(
                order: NumericFocusOrder(phoneControllers.length + 5.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: Text(
                    "Reset",
                    style: AppTextStyles.primaryButtonTextStyle
                        .copyWith(fontSize: 18),
                  ),
                  onPressed: () {
                    setState(() {
                      hoursReserved = 0;
                      minutesReserved = 0;
                      isOpenTime = false;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Open Time Toggle
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 1.4,
                    child: FocusTraversalOrder(
                      order: NumericFocusOrder(phoneControllers.length + 6.0),
                      child: Checkbox(
                        value: isOpenTime,
                        onChanged: (value) {
                          setState(() {
                            isOpenTime = value ?? false;
                            if (isOpenTime) {
                              hoursReserved = 0;
                              minutesReserved = 0;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Open Time',
                    style: AppTextStyles.tableCellStyle,
                  ),
                ],
              ),
            ),
          ),

          if ((sub != null &&
                  sub.remainingMinutes <
                      (hoursReserved * 60 + minutesReserved) &&
                  !isOpenTime) ||
              sub != null && isOpenTime)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Warning: This player has only ${sub.remainingMinutes ~/ 60} hours and ${sub.remainingMinutes % 60} minutes remaining in their subscription.',
                style: AppTextStyles.subtitleTextStyle.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  MyCard _buildPaymentCard(Map<TimeSlice, int> prices) {
    // If sub then 0 fee
    final int initialFee = _selectedPlayer?.subscriptionId == null
        ? calculatePreCheckInFee(
            hoursReserved: hoursReserved,
            minutesReserved: minutesReserved,
            prices: prices,
            isOpenTime: isOpenTime,
          )
        : 0;
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
                      ? 'Subscription Active'
                      : isOpenTime
                          ? 'Open Time'
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
          const SizedBox(height: 24),

          // Input for amount paid on check-in
          FocusTraversalOrder(
            order: NumericFocusOrder(phoneControllers.length + 7.0),
            child: TextFormField(
              controller: amountPaidController,
              style: const TextStyle(fontSize: 18),
              enabled: _selectedPlayer?.subscriptionId == null,
              decoration: InputDecoration(
                  labelText: _selectedPlayer?.subscriptionId == null
                      ? 'Amount Paid on Check-in'
                      : 'Subscription Active',
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
                        : () => _handleCheckIn(prices, initialFee),
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
}
