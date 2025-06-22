import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/receipt_dialog.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Provider that emits a value every second to update the timer
final tickerProvider = StreamProvider.autoDispose<void>((ref) {
  return Stream.periodic(const Duration(seconds: 1));
});

class CurrentPlayersTable extends ConsumerWidget {
  const CurrentPlayersTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Access the current players provider
    final currentPlayersAsyncValue = ref.watch(currentPlayersProvider);
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
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
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
                    .map((player) => _createDataRow(context, player, ref))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _createDataRow(BuildContext context, Player player, WidgetRef ref) {
    final String checkInTime =
        DateFormat('h:mm a').format(player.checkInTime.toLocal());

    return DataRow(cells: [
      DataCell(Text(player.name)),
      DataCell(Text('${player.age}')),
      DataCell(Text(checkInTime)),
      player.isOpenTime
          ? DataCell(const Text('Open Time'))
          : DataCell(
              Consumer(
                builder: (context, ref, child) {
                  ref.watch(tickerProvider);

                  // Recalculate the duration and string inside the cell
                  final Duration timeRemaining = player.checkInTime
                      .add(player.timeReserved)
                      .difference(DateTime.now());

                  String timeRemainingString;
                  if (timeRemaining.isNegative) {
                    timeRemainingString = 'Time Up!';
                  } else {
                    final hours = timeRemaining.inHours;
                    final minutes = timeRemaining.inMinutes.remainder(60);
                    timeRemainingString = '$hours h $minutes m';
                  }
                  return Text(timeRemainingString);
                },
              ),
            ),
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
    ]);
  }
}
