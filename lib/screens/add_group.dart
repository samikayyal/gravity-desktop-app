import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/time_reservation_card.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/extend_time_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/product_purchase_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/combined_providers.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:gravity_desktop_app/utils/provider_utils.dart';
import 'package:intl/intl.dart';

class GroupPlayer {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController fullNameController;
  final TextEditingController ageController;
  late PricesProductsSubs _data;

  Player? existingPlayer;
  bool isSibling;
  bool isMainSibling;

  Map<int, int> productsCart;

  bool isReadOnly = false;

  GroupPlayer({
    required this.firstNameController,
    required this.lastNameController,
    required this.fullNameController,
    required this.ageController,
    required PricesProductsSubs data,
    this.existingPlayer,
    this.isSibling = false,
    this.isMainSibling = false,
  }) : productsCart = {} {
    _data = data;
  }

  String get fullName {
    if (isSibling) {
      return '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
          .trim();
    } else {
      return fullNameController.text.trim();
    }
  }

  int get age => int.tryParse(ageController.text) ?? -1;

  int getFee(int timeReservedMinutes, bool isOpenTime) {
    return calculateGroupPlayerFee(
        player: this,
        timeReservedMinutes: timeReservedMinutes,
        isOpenTime: isOpenTime,
        prices: _data.prices,
        allProducts: _data.allProducts);
  }

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    fullNameController.dispose();
    ageController.dispose();
  }
}

class AddGroup extends ConsumerStatefulWidget {
  final PricesProductsSubs data;
  const AddGroup(this.data, {super.key});

  @override
  ConsumerState<AddGroup> createState() => _AddGroupState();
}

class _AddGroupState extends ConsumerState<AddGroup> {
  // player variables
  late List<GroupPlayer> groupPlayers;

  String sharedLastName = '';

  int timeReservedMinutes = 0;
  bool isOpenTime = false;

  int totalFee = 0;

  // state variables
  final _formKey = GlobalKey<FormState>();
  int selectedPlayerIndex = 0;
  final amountPaidController = TextEditingController();
  final List<TextEditingController> phoneControllers = [
    TextEditingController()
  ];

  // misc
  final formatter = NumberFormat.decimalPattern();

  @override
  void initState() {
    groupPlayers = [
      GroupPlayer(
          firstNameController: TextEditingController(),
          lastNameController: TextEditingController(),
          fullNameController: TextEditingController(),
          ageController: TextEditingController(),
          data: widget.data)
    ];
    super.initState();
  }

  void _incrementTime(TimeIncrement increment) {
    if (timeReservedMinutes > 60 * 12) return;

    setState(() {
      if (!isOpenTime) {
        if (increment == TimeIncrement.hour) {
          timeReservedMinutes += 60;
        } else if (increment == TimeIncrement.halfHour) {
          timeReservedMinutes += 30;
        }
      }
    });
    _updateTotalFee();
  }

  void _updateTotalFee() {
    int total = 0;
    for (var player in groupPlayers) {
      total += player.getFee(timeReservedMinutes, isOpenTime);
    }

    setState(() {
      totalFee = total;
    });
  }

  void _addPlayer() {
    if (groupPlayers.length >= maxPlayersInGroup) return;

    setState(() {
      groupPlayers.add(GroupPlayer(
          firstNameController: TextEditingController(),
          lastNameController: TextEditingController(),
          fullNameController: TextEditingController(),
          ageController: TextEditingController(),
          data: widget.data));
    });
    _updateTotalFee();
  }

  void _removePlayer(int index) {
    if (groupPlayers.length <= 1 || index < 0 || index >= groupPlayers.length) {
      return;
    }

    setState(() {
      final removedPlayer = groupPlayers[index];

      // If removing the main sibling, reassign main role
      if (removedPlayer.isMainSibling) {
        _reassignMainSibling(excludeIndex: index);
      }

      // Dispose controllers
      removedPlayer.dispose();
      groupPlayers.removeAt(index);

      // If the selected player is removed, select the first one
      if (selectedPlayerIndex == index) {
        selectedPlayerIndex = 0;
      } else if (selectedPlayerIndex >= groupPlayers.length) {
        selectedPlayerIndex = groupPlayers.length - 1;
      }
    });
    _updateTotalFee();
  }

  void _toggleSibling(int index) {
    if (index < 0 || index >= groupPlayers.length) return;

    setState(() {
      final player = groupPlayers[index];

      if (player.isSibling) {
        // Unchecking sibling - preserve combined name in full name field
        final combinedName =
            '${player.firstNameController.text.trim()} ${player.lastNameController.text.trim()}'
                .trim();
        player.fullNameController.text = combinedName;
        player.firstNameController.clear();
        player.lastNameController.clear();
        player.isSibling = false;

        // If this was the main sibling, reassign main role
        if (player.isMainSibling) {
          player.isMainSibling = false;
          _reassignMainSibling();
        }
      } else {
        // Checking sibling
        final fullName = player.fullNameController.text.trim();
        final nameParts = fullName.split(' ');

        if (nameParts.length >= 2) {
          player.firstNameController.text = nameParts.first;
          player.lastNameController.text = nameParts.sublist(1).join(' ');
        } else if (nameParts.length == 1) {
          player.firstNameController.text = nameParts.first;
        }

        player.fullNameController.clear();
        player.isSibling = true;

        // Set as main sibling if no main sibling exists
        if (!_hasMainSibling()) {
          player.isMainSibling = true;
          sharedLastName = player.lastNameController.text;
        } else {
          // Use shared last name
          player.lastNameController.text = sharedLastName;
        }
      }

      _updateSharedLastName();
    });
  }

  void _reassignMainSibling({int? excludeIndex}) {
    // Find first sibling that's not the excluded index
    for (int i = 0; i < groupPlayers.length; i++) {
      if (excludeIndex != null && i == excludeIndex) continue;

      if (groupPlayers[i].isSibling) {
        groupPlayers[i].isMainSibling = true;
        sharedLastName = groupPlayers[i].lastNameController.text;
        _updateAllSiblingLastNames();
        return;
      }
    }

    // No siblings left
    sharedLastName = '';
  }

  bool _hasMainSibling() {
    return groupPlayers.any((player) => player.isMainSibling);
  }

  void _updateSharedLastName() {
    final mainSibling = groupPlayers.firstWhere(
      (player) => player.isMainSibling,
      orElse: () => groupPlayers.first,
    );

    if (mainSibling.isMainSibling) {
      sharedLastName = mainSibling.lastNameController.text;
      _updateAllSiblingLastNames();
    }
  }

  void _updateAllSiblingLastNames() {
    for (final player in groupPlayers) {
      if (player.isSibling && !player.isMainSibling) {
        player.lastNameController.text = sharedLastName;
      }
    }
  }

  Future<void> _fillPlayerDetails(Player selection, int index) async {
    final List<String> playerPhones =
        await ref.read(playerPhonesProvider(selection.playerID).future);

    final player = groupPlayers[index];

    // set sibling to false
    if (player.isSibling) {
      _toggleSibling(index);
    }

    setState(() {
      player.fullNameController.text = selection.name;
      player.ageController.text = selection.age.toString();

      for (var playerPhone in playerPhones) {
        if (playerPhone.isEmpty) continue;
        // Add phone number only if it's not already in the list
        if (!phoneControllers
            .any((controller) => controller.text == playerPhone)) {
          // Find an empty controller to fill, otherwise add a new one.
          final emptyControllerIndex =
              phoneControllers.indexWhere((c) => c.text.isEmpty);

          if (emptyControllerIndex != -1) {
            // An empty controller is available, so use it.
            phoneControllers[emptyControllerIndex].text = playerPhone;
          } else {
            // All controllers are full, so add a new one.
            phoneControllers.add(TextEditingController(text: playerPhone));
          }
        }
      }

      player.isReadOnly = true;
    });
  }

  Future<void> _handleCheckIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(currentPlayersProvider.notifier).checkInGroup(
        groupPlayers: groupPlayers,
        timeReservedMinutes: timeReservedMinutes,
        isOpenTime: isOpenTime,
        amountPaid: int.parse(amountPaidController.text));

    refreshAllProviders(ref);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FractionallySizedBox(
        widthFactor: 0.95,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: Products and Time reservation
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildProductsCard(),
                  const SizedBox(height: 16),
                  _buildTimeReservationCard(),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Middle column: player data entry
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPlayersCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right column: Payment summary
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPhoneNumbersCard(),
                    _buildPaymentCard(),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  MyCard _buildProductsCard() {
    final selectedPlayer = groupPlayers[selectedPlayerIndex];

    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Products', style: AppTextStyles.sectionHeaderStyle),
          const SizedBox(height: 16),
          if (groupPlayers.length > 1) ...[
            Text(
              'Buying for: ${selectedPlayer.fullName.isNotEmpty ? selectedPlayer.fullName : 'Player ${selectedPlayerIndex + 1}'}',
              style: AppTextStyles.regularTextStyle
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
          widget.data.allProducts.isEmpty
              ? Center(
                  heightFactor: 3,
                  child: Text(
                    'No products available for purchase.',
                    style: AppTextStyles.subtitleTextStyle,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.data.allProducts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = widget.data.allProducts[index];
                    final quantityInCart =
                        selectedPlayer.productsCart[product.id] ?? 0;
                    return ProductListItem(
                      product: product,
                      quantity: quantityInCart,
                      onQuantityChanged: (newQuantity) {
                        if (newQuantity < 0 ||
                            newQuantity > product.effectiveStock) {
                          return;
                        }
                        setState(() {
                          if (newQuantity > 0) {
                            selectedPlayer.productsCart[product.id] =
                                newQuantity;
                          } else {
                            selectedPlayer.productsCart.remove(product.id);
                          }
                        });
                        _updateTotalFee();
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTimeReservationCard() {
    return TimeReservationCard(
        title: "Time Reservation (All Players)",
        time: Duration(minutes: timeReservedMinutes),
        isOpenTime: isOpenTime,
        oneHourOnPressed: () => _incrementTime(TimeIncrement.hour),
        halfHourOnPressed: () => _incrementTime(TimeIncrement.halfHour),
        resetOnPressed: () {
          setState(() {
            timeReservedMinutes = 0;
            isOpenTime = false;
          });
          _updateTotalFee();
        },
        isOpenTimeOnChanged: (value) {
          setState(() {
            isOpenTime = value ?? false;
            if (isOpenTime) {
              timeReservedMinutes = 0;
            }
          });
          _updateTotalFee();
        });
  }

  MyCard _buildPlayersCard() {
    return MyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Players',
                style: AppTextStyles.sectionHeaderStyle
                    .copyWith(color: Colors.black),
              ),
              ElevatedButton.icon(
                onPressed:
                    groupPlayers.length < maxPlayersInGroup ? _addPlayer : null,
                icon: const Icon(Icons.add),
                label: const Text('Add Player'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Players List - expand and scroll as needed
          ...groupPlayers.asMap().entries.map((entry) {
            final index = entry.key;
            return Column(
              children: [
                _buildPlayerForm(index),
                if (index < groupPlayers.length - 1) const Divider(height: 24),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlayerForm(int index) {
    final player = groupPlayers[index];
    final isFirst = index == 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: player.isMainSibling
            ? Border.all(color: Colors.blue.shade300)
            : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player header with sibling checkbox and product selection radio button
          Row(
            children: [
              Radio<int>(
                value: index,
                groupValue: selectedPlayerIndex,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedPlayerIndex = value;
                    });
                  }
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                'Player ${index + 1}',
                style: AppTextStyles.regularTextStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: player.isMainSibling ? Colors.blue.shade700 : null,
                ),
              ),
              if (player.isMainSibling) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text(
                    'Main Sibling',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: player.isSibling,
                    onChanged: player.isReadOnly
                        ? null
                        : (value) => _toggleSibling(index),
                  ),
                  const Text('Sibling'),
                ],
              ),
              if (!isFirst) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removePlayer(index),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  tooltip: 'Remove Player',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Name fields
          // First name and Last name fields for siblings
          Row(
            children: [
              if (player.isSibling) ...[
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: player.firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (player.isMainSibling) {
                        _updateSharedLastName();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: player.lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    enabled: player.isMainSibling,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (player.isMainSibling) {
                        _updateSharedLastName();
                      }
                    },
                  ),
                ),
              ] else ...[
                // Full name field for non-siblings
                Expanded(
                  flex: 4,
                  child: Autocomplete<Player>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Player>.empty();
                        }
                        return ref.watch(pastPlayersProvider).maybeWhen(
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
                                  threshold: fuzzyThreshold,
                                ),
                              );

                              final results =
                                  fuse.search(textEditingValue.text);
                              return results.map((result) => result.item).where(
                                  (p) =>
                                      p.subscriptionId == null &&
                                      groupPlayers.every((gp) =>
                                          gp.existingPlayer?.playerID !=
                                          p.playerID));
                            },
                            orElse: () => const Iterable<Player>.empty());
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 250, maxWidth: 400),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);

                                  final bool isHighlighted =
                                      AutocompleteHighlightedOption.of(
                                              context) ==
                                          index;
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Container(
                                      color: isHighlighted
                                          ? Theme.of(context)
                                              .focusColor
                                              .withAlpha(18)
                                          : null,
                                      child: ListTile(
                                        selected: isHighlighted,
                                        selectedTileColor:
                                            Colors.black.withAlpha(25),
                                        title: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            option.subscriptionId != null
                                                ? '${option.name} (${option.age}) - Subscription Active'
                                                : '${option.name} (${option.age})',
                                            style:
                                                AppTextStyles.regularTextStyle,
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
                        player.existingPlayer = selection;
                        await _fillPlayerDetails(selection, index);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          readOnly: player.isReadOnly,
                          onFieldSubmitted: (value) => onFieldSubmitted(),
                          onChanged: (value) {
                            // if the user is typing and not selecting
                            if (value.isNotEmpty && !player.isReadOnly) {
                              player.fullNameController.text = value;
                            }
                          },
                          style: AppTextStyles.regularTextStyle,
                          decoration: InputDecoration(
                            filled: player.isReadOnly,
                            fillColor: player.isReadOnly
                                ? Colors.grey.shade200
                                : Colors.transparent,
                            labelText:
                                player.isReadOnly ? "Name (Locked)" : 'Name',
                            labelStyle: AppTextStyles.regularTextStyle,
                            hintText: 'Enter player name',
                            hintStyle: AppTextStyles.subtitleTextStyle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            suffixIcon: player.existingPlayer != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.clear,
                                            size: 24, color: Colors.red),
                                        tooltip: 'Clear Selected Player',
                                        onPressed: () async {
                                          setState(() {
                                            player.isReadOnly = false;
                                            player.fullNameController.clear();
                                            controller.clear();
                                            player.firstNameController.clear();
                                            player.lastNameController.clear();
                                            player.ageController.clear();

                                            player.existingPlayer = null;
                                          });
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
                        );
                      }),
                ),
              ],
              const SizedBox(width: 12),
              // Age field
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: player.ageController,
                  readOnly: player.isReadOnly,
                  style: AppTextStyles.regularTextStyle,
                  decoration: InputDecoration(
                    filled: player.isReadOnly,
                    fillColor: player.isReadOnly
                        ? Colors.grey.shade200
                        : Colors.transparent,
                    labelText: player.isReadOnly ? "Age (Locked)" : 'Age',
                    labelStyle: AppTextStyles.regularTextStyle,
                    hintText: 'Enter player age',
                    hintStyle: AppTextStyles.subtitleTextStyle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Age is required';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 0) {
                      return 'Enter a valid age';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  MyCard _buildPaymentCard() {
    return MyCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Payment Summary',
            style:
                AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
          ),

          // detailed fee for each player
          for (var player in groupPlayers)
            Text(
                "${player.fullName.isNotEmpty ? player.fullName : 'Player ${groupPlayers.indexOf(player) + 1}'} Fee: ${player.getFee(timeReservedMinutes, isOpenTime)}",
                style: AppTextStyles.regularTextStyle
                    .copyWith(fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),
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
                  isOpenTime
                      ? totalFee == 0
                          ? 'Open Time'
                          : 'Open Time - ${formatter.format(totalFee)} SYP'
                      : '${formatter.format(totalFee)}  SYP',
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
          // pay in full button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: AppButtonStyles.primaryButton,
                onPressed: () {
                  setState(() {
                    amountPaidController.text = '$totalFee';
                  });
                },
                child: Text("Pay in Full",
                    style: AppTextStyles.primaryButtonTextStyle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: amountPaidController,
            style: AppTextStyles.regularTextStyle,
            decoration: InputDecoration(
                labelText: 'Amount Paid on Check-in',
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
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              final amount = int.tryParse(value);
              if (amount == null || amount < 0) {
                return 'Please enter a valid amount';
              }
              if (amount > totalFee) {
                return 'Amount is more than the total fee';
              }
              return null;
            },
          ),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 60,
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
                  timeReservedMinutes == 0 && !isOpenTime
                      ? null
                      : () async => await _handleCheckIn(),
              child: const Text("Add Player"),
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
                    child: TextFormField(
                      controller: phoneControllers[i],
                      style: AppTextStyles.regularTextStyle,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

  @override
  void dispose() {
    for (final player in groupPlayers) {
      player.dispose();
    }
    super.dispose();
  }
}
