import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/phone_number_entry.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/time_reservation_card.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/extend_time_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/product_purchase_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/cards/my_card.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text_field.dart';
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
    final List<PlayerPhone> playerPhones =
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
        if (playerPhone.number.isEmpty) continue;
        // Add phone number only if it's not already in the list
        if (!phoneControllers
            .any((controller) => controller.text == playerPhone.number)) {
          // Find an empty controller to fill, otherwise add a new one.
          final emptyControllerIndex =
              phoneControllers.indexWhere((c) => c.text.isEmpty);

          if (emptyControllerIndex != -1) {
            // An empty controller is available, so use it.
            phoneControllers[emptyControllerIndex].text = playerPhone.number;
          } else {
            // All controllers are full, so add a new one.
            phoneControllers
                .add(TextEditingController(text: playerPhone.number));
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
                    PhoneNumberEntryCard(
                      title: "Phone Numbers",
                      controllers: phoneControllers,
                      isDisabled: groupPlayers.any((p) => p.isReadOnly),
                      disableListModification: false,
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
          // Header with improved styling
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.groups,
                      color: Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Players',
                      style: AppTextStyles.sectionHeaderStyle.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: groupPlayers.length < maxPlayersInGroup
                      ? _addPlayer
                      : null,
                  style: AppButtonStyles.primaryButton,
                  icon: const Icon(
                    Icons.add,
                    size: 20,
                    color: mainBlue,
                  ),
                  label: Text(
                    'Add Player',
                    style: AppTextStyles.primaryButtonTextStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: player.isMainSibling
            ? Border.all(color: Colors.blue.shade400, width: 2)
            : Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // player radio button
                  Container(
                    decoration: BoxDecoration(
                      color: selectedPlayerIndex == index
                          ? Colors.blue.shade100
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Radio<int>(
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
                      activeColor: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    player.isSibling ? Icons.people : Icons.person,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    player.isSibling
                        ? 'Sibling Information'
                        : 'Player Information',
                    style: AppTextStyles.regularTextStyle,
                  ),
                  if (player.isMainSibling) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.family_restroom,
                            size: 12,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Main Sibling',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: player.isSibling
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: player.isSibling
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: player.isSibling,
                            onChanged: player.isReadOnly
                                ? null
                                : (value) => _toggleSibling(index),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeColor: Colors.green.shade600,
                          ),
                        ),
                        Text(
                          'Sibling',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: player.isSibling
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isFirst) ...[
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () => _removePlayer(index),
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.red.shade600,
                        tooltip: 'Remove Player',
                        iconSize: 20,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (player.isSibling) ...[
                    Expanded(
                      flex: 2,
                      child: MyTextField(
                        controller: player.firstNameController,
                        labelText: 'First Name',
                        hintText: 'Enter first name',
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
                      child: MyTextField(
                        controller: player.lastNameController,
                        isDisabled: !player.isMainSibling,
                        labelText: 'Last Name',
                        hintText: player.isMainSibling
                            ? 'Enter last name'
                            : 'Shared with main sibling',
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
                                            getter: (Player player) =>
                                                player.name)
                                      ],
                                      threshold: fuzzyThreshold,
                                    ),
                                  );

                                  final results =
                                      fuse.search(textEditingValue.text);
                                  return results
                                      .map((result) => result.item)
                                      .where((p) =>
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
                                borderRadius: BorderRadius.circular(12),
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
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Text(
                                                option.subscriptionId != null
                                                    ? '${option.name} (${option.age}) - Subscription Active'
                                                    : '${option.name} (${option.age})',
                                                style: AppTextStyles
                                                    .regularTextStyle,
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
                          displayStringForOption: (Player option) =>
                              option.name,
                          onSelected: (Player selection) async {
                            player.existingPlayer = selection;
                            await _fillPlayerDetails(selection, index);
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
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
                                filled: true,
                                fillColor: player.isReadOnly
                                    ? Colors.grey.shade100
                                    : Colors.white,
                                labelText: player.isReadOnly
                                    ? "Name (Locked)"
                                    : 'Full Name',
                                labelStyle:
                                    AppTextStyles.regularTextStyle.copyWith(
                                  color: player.isReadOnly
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600,
                                ),
                                hintText: 'Enter player name',
                                hintStyle: AppTextStyles.subtitleTextStyle,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blue.shade400, width: 2),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                prefixIcon: player.isReadOnly
                                    ? Icon(
                                        Icons.lock_outline,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      )
                                    : null,
                                suffixIcon: player.existingPlayer != null
                                    ? Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            size: 20,
                                            color: Colors.red.shade600,
                                          ),
                                          tooltip: 'Clear Selected Player',
                                          onPressed: () async {
                                            setState(() {
                                              player.isReadOnly = false;
                                              player.fullNameController.clear();
                                              controller.clear();
                                              player.firstNameController
                                                  .clear();
                                              player.lastNameController.clear();
                                              player.ageController.clear();
                                              player.existingPlayer = null;
                                            });
                                          },
                                        ),
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
                  // Age field with improved styling
                  Expanded(
                    flex: 1,
                    child: MyTextField(
                      controller: player.ageController,
                      isDisabled: player.isReadOnly,
                      labelText: 'Age',
                      hintText: 'Age',
                      isNumberInputOnly: true,
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
            ],
          ),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          MyTextField(
            controller: amountPaidController,
            labelText: 'Amount Paid on Check-in',
            hintText: 'Enter amount paid',
            prefixText: 'SYP   ',
            isNumberInputOnly: true,
            borderRadius: 10.0,
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

  @override
  void dispose() {
    for (final player in groupPlayers) {
      player.dispose();
    }
    super.dispose();
  }
}
