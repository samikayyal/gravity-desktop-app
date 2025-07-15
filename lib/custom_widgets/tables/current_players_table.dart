// ignore: unused_import
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/extend_time_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/product_purchase_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_materialbanner.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/tables/table.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';
import 'package:gravity_desktop_app/screens/receipt.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

// Provider that emits a value every second to update the timer
final tickerProvider = StreamProvider.autoDispose<void>((ref) {
  return Stream.periodic(const Duration(seconds: 20));
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
    _audioPlayer.play(AssetSource('short-beep.mp3'));

    // Show a banner at the bottom
    MyMaterialBanner.showFloatingBanner(context,
        message: "Time for player ${player.name} is almost up!");
  }

  Future<void> _goToReceipt(BuildContext context, Player player) async {
    await ref.read(pricesProvider.notifier).refresh();
    await ref.read(productsProvider.notifier).refresh();

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Receipt(player.sessionID),
        ),
      );

      // showDialog(context: context, builder:
      // (context) => ReceiptDialog(player)
      // );
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

        // Use a vertically scrollable table that fills the available space
        return TableContainer(
            columnHeaders: [
              'Name',
              'Age',
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
              0: const FlexColumnWidth(2.5), // Name (wider)
              1: const FlexColumnWidth(0.7), // Age (narrower)
              2: const FlexColumnWidth(1.2), // Check-in
              3: const FlexColumnWidth(1.2), // Time left
              4: const FlexColumnWidth(1.0), // Fee
              5: const FlexColumnWidth(1.0), // Paid
              6: const FlexColumnWidth(1.0), // Left
              7: const FlexColumnWidth(2.5), // Actions (wider)
            });
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

    if (!player.isOpenTime) {
      final Duration timeRemaining = player.checkInTime
          .add(player.timeReserved)
          .difference(DateTime.now());

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
        Row(
          children: [
            Container(width: 4.0, color: groupColor, child: Text("")),
            const SizedBox(
              width: 4,
            ),
            buildDataCell(player.name, style: cellStyle)
          ],
        ),
        buildDataCell('${player.age}', style: cellStyle),
        buildDataCell(checkInTime, style: cellStyle),
        buildDataCell(
          timeRemainingString,
          style: isTimeUp
              ? timeUpStyle
              : isAlmostTimeUp
                  ? almostTimeUpStyle
                  : cellStyle,
        ),
        buildDataCell(
          player.isOpenTime ? 'Open' : '${player.initialFee}',
          style: amountStyle,
        ),
        buildDataCell('${player.amountPaid}', style: amountStyle),
        buildDataCell(
          player.isOpenTime
              ? 'Open'
              : '${player.initialFee - player.amountPaid}',
          style: amountStyle,
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
              )
            ],
          ),
        ),
      ],
    );
  }
}
