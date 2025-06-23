import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/receipt_dialog.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart'; // NEW: Import for sound

// Provider that emits a value every second to update the timer
final tickerProvider = StreamProvider.autoDispose<void>((ref) {
  return Stream.periodic(const Duration(seconds: 20));
});

// MODIFIED: Converted to a ConsumerStatefulWidget to manage state
class CurrentPlayersTable extends ConsumerStatefulWidget {
  const CurrentPlayersTable({super.key});

  @override
  ConsumerState<CurrentPlayersTable> createState() =>
      _CurrentPlayersTableState();
}

class _CurrentPlayersTableState extends ConsumerState<CurrentPlayersTable> {
  late final AudioPlayer _audioPlayer;
  final Set<String> _alertedPlayerIds = {};

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
          title: const Text("Time's Up!"),
          content: Text("Time for player ${player.name} has expired."),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Check Out'),
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
        child: Text('Table Error: $error \n$stackTrace'),
      ),
      data: (currentPlayers) {
        if (currentPlayers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No current players',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Use a horizontal scrollable table for better display on constrained width
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Age')),
                DataColumn(label: Text('Check-in')),
                DataColumn(label: Text('Time Left')),
                DataColumn(label: Text('Fee')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Left')),
                DataColumn(label: Text('Actions')),
              ],
              rows: currentPlayers
                  .map((player) => _createDataRow(context, player))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _createDataRow(BuildContext context, Player player) {
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

    return DataRow(
      // Set the row color to red if time is up
      color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        return isTimeUp ? Colors.red.withAlpha((0.3 * 255).toInt()) : null;
      }),
      cells: [
        DataCell(Text(player.name)),
        DataCell(Text('${player.age}')),
        DataCell(Text(checkInTime)),
        //  The timer cell is now a simple Text widget, no Consumer needed
        DataCell(Text(timeRemainingString)),
        DataCell(Text(player.isOpenTime ? 'Open' : '${player.initialFee}')),
        DataCell(Text('${player.amountPaid}')),
        DataCell(
          Text(
            player.isOpenTime
                ? 'Open'
                : '${player.initialFee - player.amountPaid}',
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Check Out Button
              IconButton(
                  tooltip: 'Check Out',
                  icon: const Icon(Icons.logout, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ReceiptDialog(player),
                    );
                  }),

              // Add Product Button
              IconButton(
                tooltip: 'Add Product',
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
