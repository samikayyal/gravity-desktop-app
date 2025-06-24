import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/receipt_dialog.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
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

  // Scrolling controller for vertical scrolling only
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _verticalController.dispose();
    super.dispose();
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
              onPressed: () {
                Navigator.of(context).pop();
                // Trigger the check out dialog
                showDialog(
                  context: context,
                  builder: (context) => ReceiptDialog(player),
                );
              },
            ),
          ],
        );
      },
    );
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

        // Use a vertically scrollable table that fills the available space
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(50),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            thickness: 8,
            radius: const Radius.circular(4),
            child: SingleChildScrollView(
              controller: _verticalController,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Table(
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    columnWidths: {
                      0: const FlexColumnWidth(2.5), // Name (wider)
                      1: const FlexColumnWidth(0.8), // Age (narrower)
                      2: const FlexColumnWidth(1.5), // Check-in
                      3: const FlexColumnWidth(1.5), // Time Left
                      4: const FlexColumnWidth(1.0), // Fee
                      5: const FlexColumnWidth(1.0), // Paid
                      6: const FlexColumnWidth(1.0), // Left
                      7: const FlexColumnWidth(2.5), // Actions (wider)
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      // Header Row
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F5F5),
                        ),
                        children: [
                          _buildHeaderCell('Name'),
                          _buildHeaderCell('Age'),
                          _buildHeaderCell('Check-in'),
                          _buildHeaderCell('Time Left'),
                          _buildHeaderCell('Fee'),
                          _buildHeaderCell('Paid'),
                          _buildHeaderCell('Left'),
                          _buildHeaderCell('Actions'),
                        ],
                      ),
                      // Data Rows
                      ...currentPlayers
                          .map((player) => _buildTableRow(context, player)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build header cells
  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Text(
        text,
        style: AppTextStyles.sectionHeaderStyle.copyWith(fontSize: 18),
      ),
    );
  }

  // Helper method to build regular data cells
  Widget _buildDataCell(String text, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: style ?? AppTextStyles.regularTextStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Create a table row for each player
  TableRow _buildTableRow(BuildContext context, Player player) {
    final String checkInTime =
        DateFormat('h:mm a').format(player.checkInTime.toLocal());

    bool isTimeUp = false;
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
      } else {
        final hours = timeRemaining.inHours;
        final minutes = timeRemaining.inMinutes.remainder(60);
        timeRemainingString = '$hours h $minutes m';
      }
    }

    final TextStyle cellStyle = AppTextStyles.tableCellStyle;
    final TextStyle amountStyle = AppTextStyles.amountTextStyle;
    final TextStyle timeUpStyle = cellStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.red,
    );

    return TableRow(
      decoration: BoxDecoration(
        color: isTimeUp ? Colors.red.withAlpha((0.1 * 255).toInt()) : null,
      ),
      children: [
        _buildDataCell(player.name, style: cellStyle),
        _buildDataCell('${player.age}', style: cellStyle),
        _buildDataCell(checkInTime, style: cellStyle),
        _buildDataCell(
          timeRemainingString,
          style: isTimeUp ? timeUpStyle : cellStyle,
        ),
        _buildDataCell(
          player.isOpenTime ? 'Open' : '${player.initialFee}',
          style: amountStyle,
        ),
        _buildDataCell('${player.amountPaid}', style: amountStyle),
        _buildDataCell(
          player.isOpenTime
              ? 'Open'
              : '${player.initialFee - player.amountPaid}',
          style: amountStyle,
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.logout, size: 23),
                label: Text(
                  "Checkout",
                  style: AppTextStyles.primaryButtonTextStyle,
                ),
                style: AppButtonStyles.primaryButton.copyWith(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ReceiptDialog(player),
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add Product',
                icon: const Icon(Icons.add_shopping_cart, size: 22),
                style: AppButtonStyles.iconButtonCircle,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
