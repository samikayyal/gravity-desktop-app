import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/current_players_table.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/screens/add_player.dart';
import 'package:gravity_desktop_app/screens/edit_prices.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(),
      body: Column(
        children: [
          // Row with table, TODO: Add more widgets, other side should have inventory and shit
          Row(
            children: [
              Column(
                children: [
                  // button to add a player
                  Row(
                    children: [
                      ElevatedButton(
                          child: const Text('Add Player'),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AddPlayerScreen()));
                          }),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        child: Text("Edit Prices"),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EditPricesScreen(),
                            ),
                          );
                        },
                      )
                    ],
                  ),

                  // players table
                  CurrentPlayersTable(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
