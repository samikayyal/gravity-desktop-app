import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:intl/intl.dart';

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
            rows:
                currentPlayers.map((player) => _createDataRow(player)).toList(),
          ),
        );
      },
    );
  }

  DataRow _createDataRow(Player player) {
    final String checkInTime =
        DateFormat('h:mm a').format(player.checkInTime.toLocal());
    final Duration timeRemaining =
        player.checkInTime.add(player.timeReserved).difference(DateTime.now());

    return DataRow(cells: [
      DataCell(Text(player.name)),
      DataCell(Text('${player.age}')),
      DataCell(Text(checkInTime)),
      DataCell(Text(player.isOpenTime
          ? 'Open Time'
          : '${timeRemaining.inHours}h ${timeRemaining.inMinutes % 60}m')),
      DataCell(Text('${player.totalFee}')),
      DataCell(Text('${player.totalFee - player.amountPaid}')),
      DataCell(
        Row(
          children: [
            // Check Out Button
            TextButton(onPressed: () {}, child: const Text('Check Out')),

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
