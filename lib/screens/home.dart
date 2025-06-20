import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Gravity Header
          Image.asset(
            'assets/gravity_header.png',
            width: double.infinity,
          ),
          // Row with table, TODO: Add more widgets, other side should have inventory and shit
          Row(
            children: [
              Column(
                children: [
                  // button to add a player
                  ElevatedButton(
                      child: const Text('Add Player'),
                      onPressed: () {
                        // TODO: Implement add player functionality
                        debugPrint('Add Player button pressed');
                      }),

                  // players table
                  DataTable(columns: const [
                    DataColumn(label: Text('Label')),
                    DataColumn(label: Text('Value'))
                  ], rows: const [
                    DataRow(
                        cells: [DataCell(Text('Data')), DataCell(Text('Data'))])
                  ]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
