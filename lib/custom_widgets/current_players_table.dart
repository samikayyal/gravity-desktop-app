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
        child: Text('Table Error: $error'),
      ),
      data: (currentPlayers) {
        if (currentPlayers.isEmpty) {
          return SingleChildScrollView(
              child: const Center(child: Text('No current players')));
        }
        return SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Age')),
              DataColumn(label: Text('Check-in Time')),
              DataColumn(label: Text('Time Remaining')),
              DataColumn(label: Text('Total Fee')),
              DataColumn(label: Text('Amount Left')),
              DataColumn(label: Text('Actions')),
            ],
            rows: currentPlayers
                .map((player) => _createDataRow(context, player, ref))
                .toList(),
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
                    timeRemainingString = '$hours Hours $minutes Minutes';
                  }
                  return Text(timeRemainingString);
                },
              ),
            ),
      DataCell(Text('${player.totalFee}')),
      DataCell(Text('${player.totalFee - player.amountPaid}')),
      DataCell(
        Row(
          children: [
            // Check Out Button
            TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ReceiptDialog(player: player),
                  );
                },
                child: const Text('Check Out')),

            // Add Product Button
            TextButton(
              onPressed: () {},
              child: const Text('Add Product'),
            ),
          ],
        ),
      ),
    ]);
  }
}
