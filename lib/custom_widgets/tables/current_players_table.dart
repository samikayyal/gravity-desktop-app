// ignore: unused_import
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/extend_time_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/midsession_payment.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/product_purchase_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/tables/table.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/combined_providers.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/misc_providers.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';
import 'package:gravity_desktop_app/screens/player_details.dart';
import 'package:gravity_desktop_app/screens/receipt.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

// Provider that emits a value every second to update the timer
final tickerProvider = StreamProvider.autoDispose<void>((ref) {
  return Stream.periodic(const Duration(seconds: 1));
});

class CurrentPlayersTable extends ConsumerStatefulWidget {
  const CurrentPlayersTable({super.key});

  @override
  ConsumerState<CurrentPlayersTable> createState() =>
      _CurrentPlayersTableState();
}

class _CurrentPlayersTableState extends ConsumerState<CurrentPlayersTable> {
  late final AudioPlayer _audioPlayer;
  final Set<String> _alertedPlayerIds = {};
  final Set<String> _almostTimeAlertedPlayerIds = {};

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handlePurchase(BuildContext context, Player player) {
    showDialog(
        context: context,
        builder: (context) {
          return ProductPurchaseDialog(
            player: player,
          );
        });
  }

  void _handleTimeUp(BuildContext context, Player player) {
    setState(() {
      _alertedPlayerIds.add(player.playerID);
    });

    // Play sound
    _audioPlayer.play(AssetSource('short-beep.mp3'));

    // Show popup dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Time's Up!",
            style: AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.red),
          ),
          content: Text(
            "Time for player ${player.name} has expired.",
            style: AppTextStyles.regularTextStyle,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: AppButtonStyles.primaryButton,
              child: Text('Check Out',
                  style: AppTextStyles.primaryButtonTextStyle),
              onPressed: () async {
                Navigator.of(context).pop();
                // Trigger the check out dialog
                await _goToReceipt(context, player);
              },
            ),
          ],
        );
      },
    );
  }

  void _handleTimeAlmostUp(BuildContext context, Player player) {
    setState(() {
      _almostTimeAlertedPlayerIds.add(player.playerID);
    });
    // Play sound
    _audioPlayer.play(AssetSource('almost-beep.mp3'));

    // Show a banner at the bottom
    MyMaterialBanner.showFloatingBanner(context,
        message: "Time for player ${player.name} is almost up!");
  }

  Future<void> _goToReceipt(BuildContext context, Player? player) async {
    // if no player is provided and no selected players, throw an error
    final playersSelected = ref.read(selectedPlayersProvider);
    if (player == null && playersSelected.isEmpty) {
      MyMaterialBanner.showFloatingBanner(context,
          message: "No player selected for checkout.");
      return;
    }

    await ref.read(pricesProvider.notifier).refresh();
    await ref.read(productsProvider.notifier).refresh();
    // ONE PLAYER CHECKOUT
    if (playersSelected.isEmpty) {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Receipt([player!.sessionID]),
          ),
        );
      }
    }
    // PLAYER GROUP CHECKOUT
    else {
      final List<int> sessionIds =
          playersSelected.map((p) => p.sessionID).toList();
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Receipt(sessionIds),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayersAsyncValue = ref.watch(currentPlayersProvider);
    ref.watch(tickerProvider);

    return currentPlayersAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Table Error: $error \n$stackTrace',
          style: AppTextStyles.regularTextStyle.copyWith(color: Colors.red),
        ),
      ),
      data: (currentPlayers) {
        if (currentPlayers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                Text(
                  'No current players',
                  style: AppTextStyles.regularTextStyle.copyWith(
                    color: Colors.grey,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Players you add will appear here',
                  style: AppTextStyles.regularTextStyle.copyWith(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        // 1. Create a map to store assigned colors for each group number.
        final Map<int, Color> groupColorMap = {};
        int colorIndex = 0;

        // Find all unique, non-null group numbers and assign a color.
        for (final player in currentPlayers) {
          if (player.groupNumber != null &&
              !groupColorMap.containsKey(player.groupNumber)) {
            groupColorMap[player.groupNumber!] =
                groupColors[colorIndex % groupColors.length];
            colorIndex++;
          }
        }

        // Selected players for checkout
        final Set<Player> playersSelected = ref.watch(selectedPlayersProvider);

        return Column(
          children: [
            Expanded(
              child: TableContainer(
                  columnHeaders: [
                    '', // checkbox
                    'Name',
                    'Phone Number',
                    'Check-in',
                    'Time Left',
                    'Fee',
                    'Paid',
                    'Left',
                    'Actions'
                  ],
                  rowData: currentPlayers
                      .asMap()
                      .entries
                      .map((entry) => _buildTableRow(
                          context, entry.value, entry.key, groupColorMap))
                      .toList(),
                  columnWidths: {
                    0: const FlexColumnWidth(0.3), // checkbox
                    1: const FlexColumnWidth(2.3), // Name
                    2: const FlexColumnWidth(1.7), // Phone Number
                    3: const FlexColumnWidth(1.2), // Check-in
                    4: const FlexColumnWidth(1.3), // Time left
                    5: const FlexColumnWidth(1.0), // Fee
                    6: const FlexColumnWidth(1.0), // Paid
                    7: const FlexColumnWidth(1.0), // Left
                    8: const FlexColumnWidth(3), // actions
                  }),
            ),

            // Buttons for selected players
            if (playersSelected.length >= 2 && playersSelected.length <= 4)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 24),
                      label: Text(
                        "Checkout Selected",
                        style: AppTextStyles.primaryButtonTextStyle,
                      ),
                      style: AppButtonStyles.primaryButton.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                      onPressed: () async {
                        if (playersSelected.isEmpty) return;

                        await _goToReceipt(context, null);
                        ref
                            .read(selectedPlayersProvider.notifier)
                            .clearSelection();
                      },
                    )
                  ],
                ),
              )
          ],
        );
      },
    );
  }

  // Create a table row for each player
  TableRow _buildTableRow(BuildContext context, Player player, int index,
      Map<int, Color> groupColorMap) {
    final String checkInTime =
        DateFormat('h:mm a').format(player.checkInTime.toLocal());

    bool isTimeUp = false;
    bool isAlmostTimeUp = false;
    String timeRemainingString = 'Open Time';
    final Duration timeRemaining =
        player.checkInTime.add(player.timeReserved).difference(DateTime.now());
    final Duration timeSpent = DateTime.now().difference(player.checkInTime);
    int playerFee = player.initialFee;

    if (!player.isOpenTime) {
      if (timeRemaining.isNegative) {
        isTimeUp = true;
        timeRemainingString = 'Time Up!';

        // Check if we need to trigger an alert for this player
        if (!_alertedPlayerIds.contains(player.playerID)) {
          // We use a post-frame callback to safely show a dialog after the build is complete.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _handleTimeUp(context, player);
            }
          });
        }
      } else if (timeRemaining.inMinutes <= 3) {
        isAlmostTimeUp = true;
        final hours = timeRemaining.inHours;
        final minutes = timeRemaining.inMinutes.remainder(60);
        timeRemainingString = '$hours h $minutes m';

        if (!_almostTimeAlertedPlayerIds.contains(player.playerID)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _handleTimeAlmostUp(context, player);
            }
          });
        }
      } else {
        final hours = timeRemaining.inHours;
        final minutes = timeRemaining.inMinutes.remainder(60);
        timeRemainingString = '$hours h $minutes m';
      }
    }

    // textstyles
    final TextStyle cellStyle = AppTextStyles.tableCellStyle;
    final TextStyle amountStyle = AppTextStyles.amountTextStyle;
    final TextStyle almostTimeUpStyle = AppTextStyles.tableCellStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.orange.shade500,
    );
    final TextStyle timeUpStyle = cellStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.red,
    );

    // Get the color for the player's group, if any.
    final Color? groupColor =
        (player.groupNumber != null && player.groupNumber != 0)
            ? groupColorMap[player.groupNumber!]
            : null;

    return TableRow(
      decoration: BoxDecoration(
        color: isTimeUp
            ? Colors.red.withAlpha(30)
            : isAlmostTimeUp
                ? Colors.orange.withAlpha(30)
                : (index.isEven
                    ? TableThemes.evenRowColor
                    : TableThemes.oddRowColor),
      ),
      children: [
        // checkbox
        Consumer(
          builder: (context, ref, child) {
            final selectedPlayers = ref.watch(selectedPlayersProvider);

            return Checkbox(
              activeColor: Colors.blue,
              value: selectedPlayers.contains(player),
              onChanged: (value) {
                if (player.subscriptionId != null) {
                  MyMaterialBanner.showFloatingBanner(context,
                      message: "Cannot select players with subscriptions.");
                  return;
                }
                ref.read(selectedPlayersProvider.notifier).togglePlayer(player);
              },
            );
          },
        ),

        // name and group color if exists
        Row(
          children: [
            Container(width: 4.0, color: groupColor, child: Text("")),
            const SizedBox(
              width: 4,
            ),
            GestureDetector(
                onDoubleTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => PlayerDetails(player)));
                },
                child: buildDataCell(player.name, style: cellStyle))
          ],
        ),
        Consumer(builder: (context, ref, child) {
          final playerPhones = ref.watch(playerPhonesProvider(player.playerID));
          return playerPhones.when(
            loading: () => buildDataCell('Loading...', style: cellStyle),
            error: (error, stackTrace) => buildDataCell(
              'Error',
              style: cellStyle.copyWith(color: Colors.red),
            ),
            data: (phones) {
              return buildDataCell(
                phones.isNotEmpty
                    ? phones
                        .firstWhere(
                          (phone) => phone.isPrimary,
                          orElse: () =>
                              PlayerPhone(number: 'No Phone', isPrimary: false),
                        )
                        .number
                    : 'No Phone',
                style: cellStyle,
              );
            },
          );
        }),
        buildDataCell(checkInTime, style: cellStyle),
        buildDataCell(
          timeRemainingString,
          style: isTimeUp
              ? timeUpStyle
              : isAlmostTimeUp
                  ? almostTimeUpStyle
                  : cellStyle,
        ),
        // Player fee
        Consumer(
          builder: (context, ref, child) {
            return ref.watch(pricesProductsSubsProvider).when(
                  loading: () => buildDataCell("Loading...", style: cellStyle),
                  error: (error, stackTrace) =>
                      buildDataCell("Error", style: amountStyle),
                  data: (data) {
                    playerFee = calculateFinalFee(
                        timeReserved: player.timeReserved,
                        isOpenTime: player.isOpenTime,
                        timeSpent: timeSpent,
                        prices: data.prices,
                        productsBought: player.productsBought,
                        allProducts: data.allProducts);

                    return buildDataCell("$playerFee", style: amountStyle);
                  },
                );
          },
        ),
        buildDataCell('${player.amountPaid}', style: amountStyle),

        // Amount left
        Consumer(
          builder: (context, ref, child) {
            return ref.watch(pricesProductsSubsProvider).when(
                  loading: () => buildDataCell("Loading...", style: cellStyle),
                  error: (error, stackTrace) =>
                      buildDataCell("Error", style: amountStyle),
                  data: (data) {
                    playerFee = calculateFinalFee(
                        timeReserved: player.timeReserved,
                        isOpenTime: player.isOpenTime,
                        timeSpent: timeSpent,
                        prices: data.prices,
                        productsBought: player.productsBought,
                        allProducts: data.allProducts);

                    return buildDataCell(
                      player.isOpenTime
                          ? 'Open'
                          : '${playerFee - player.amountPaid}',
                      style: player.isOpenTime ? cellStyle : amountStyle,
                    );
                  },
                );
          },
        ),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout, size: 24),
                  label: Text(
                    "Checkout",
                    style: AppTextStyles.primaryButtonTextStyle,
                  ),
                  style: AppButtonStyles.primaryButton.copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                  ),
                  onPressed: () async => await _goToReceipt(context, player),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Buy Product',
                icon: const Icon(Icons.add_shopping_cart, size: 22),
                style: AppButtonStyles.iconButtonCircle,
                onPressed: () {
                  _handlePurchase(context, player);
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_time_outlined, size: 22),
                tooltip: 'Extend Time',
                style: AppButtonStyles.iconButtonCircle,
                onPressed: () {
                  if (player.isOpenTime) {
                    MyMaterialBanner.showFloatingBanner(context,
                        message: "Cannot extend time for open sessions.");
                    return;
                  }
                  showDialog(
                      context: context,
                      builder: (context) => ExtendTimeDialog(player));
                },
              ),
              if (player.amountPaid < player.initialFee ||
                  player.isOpenTime) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.payment, size: 22),
                  tooltip: 'Pay Remaining Fee',
                  style: AppButtonStyles.iconButtonCircle,
                  onPressed: () async {
                    await showDialog(
                        context: context,
                        builder: (context) => MidsessionPaymentDialog(player));
                  },
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}
