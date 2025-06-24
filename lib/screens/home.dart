import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/current_players_table.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';
import 'package:gravity_desktop_app/screens/add_player.dart';
import 'package:gravity_desktop_app/screens/edit_prices.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';

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
      body: Row(
        children: [
          // Left side - 65% of screen width with players table
          Container(
            width: MediaQuery.of(context).size.width * 0.65,
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title section
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Current Players',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Buttons section with title
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0, bottom: 12.0),
                        child: Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3949AB),
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 16, // Horizontal spacing between buttons
                        runSpacing:
                            16, // Vertical spacing between rows if buttons wrap
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.person_add, size: 24),
                            label: Text("Add Player",
                                style: AppTextStyles.primaryButtonTextStyle),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const AddPlayerScreen()));
                            },
                            style: AppButtonStyles.primaryButton,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit, size: 24),
                            label: Text("Edit Prices",
                                style: AppTextStyles.primaryButtonTextStyle),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EditPricesScreen(),
                                ),
                              );
                            },
                            style: AppButtonStyles.primaryButton,
                          ),

                          ElevatedButton.icon(
                            icon: const Icon(Icons.shopping_cart, size: 24),
                            label: Text("Separate Purchase",
                                style: AppTextStyles.primaryButtonTextStyle),
                            onPressed: () {
                              // Navigator.of(context).push(
                              //   MaterialPageRoute(
                              //     builder: (context) => SeparatePurchaseScreen(),
                              //   ),
                              // );
                            },
                            style: AppButtonStyles.primaryButton,
                          ),

                          // ---------- TEST SECTION ----------
                          ElevatedButton.icon(
                            icon: const Icon(Icons.person, size: 24),
                            label: const Text(
                              "Add player with 1 mins",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            onPressed: () {
                              ref
                                  .read(currentPlayersProvider.notifier)
                                  .checkInPlayer(
                                existingPlayerID: null,
                                name: "Test Player",
                                age: 99,
                                timeReservedHours: 0,
                                timeReservedMinutes: 1,
                                isOpenTime: false,
                                totalFee: calculatePreCheckInFee(
                                  hoursReserved: 0,
                                  minutesReserved: 1,
                                  prices: ref.read(pricesProvider).value!,
                                  isOpenTime: false,
                                ),
                                amountPaid: 0,
                                phoneNumbers: [],
                              );
                            },
                          ),

                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.clear_all,
                              size: 24,
                            ),
                            label: const Text(
                              "Clear All Players",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            onPressed: () async {
                              final db =
                                  ref.read(currentPlayersProvider.notifier);
                              await db.clearCurrentPlayers();
                            },
                            style: AppButtonStyles.dangerButton,
                          ),

                          // ---------- END TEST SECTION ----------
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Table with expanded to fill the rest of the column height
                Expanded(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CurrentPlayersTable(),
                    ),
                  ),
                ),
              ],
            ),
          ), // Right side - 35% of screen width for future additions
          Container(
            width: MediaQuery.of(context).size.width * 0.35,
            padding: const EdgeInsets.all(16.0),
            child: const Center(
              child: Text(
                'Future content area',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
