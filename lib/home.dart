// ignore_for_file: unused_import

import 'dart:developer';
import 'package:gravity_desktop_app/custom_widgets/debts_card.dart';
import 'package:gravity_desktop_app/custom_widgets/notes.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/date_selection_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/past_players_search.dart';
import 'package:gravity_desktop_app/custom_widgets/tables/current_players_table.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/product_purchase_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_appbar.dart';
import 'package:gravity_desktop_app/custom_widgets/my_buttons.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/custom_widgets/tables/products_table.dart';
import 'package:gravity_desktop_app/custom_widgets/revenue_card.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';
import 'package:gravity_desktop_app/screens/add_player.dart';
import 'package:gravity_desktop_app/screens/add_product.dart';
import 'package:gravity_desktop_app/screens/edit_prices.dart';
import 'package:gravity_desktop_app/screens/stats_screen.dart';
import 'package:gravity_desktop_app/screens/subscriptions.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
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
      appBar: MyAppBar(
        isHomeScreen: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const PastPlayersSearch(),
          );
        },
        tooltip: 'Search Past Players',
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.search, size: 24),
      ),
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
                            color: mainBlue,
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
                            onPressed: () async {
                              if (context.mounted) {
                                ref
                                    .read(pastPlayersProvider.notifier)
                                    .refresh();
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const AddPlayerScreen()));
                              }
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
                              showDialog(
                                context: context,
                                builder: (context) => ProductPurchaseDialog(),
                              );
                            },
                            style: AppButtonStyles.primaryButton,
                          ),

                          // ---------- TEST SECTION ----------
                          ElevatedButton.icon(
                            icon: const Icon(Icons.person, size: 24),
                            label: const Text(
                              "1 min",
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
                                timeReservedMinutes: 1,
                                isOpenTime: false,
                                totalFee: calculatePreCheckInFee(
                                  hoursReserved: 0,
                                  minutesReserved: 1,
                                  timeExtendedMinutes: 0,
                                  prices: ref.read(pricesProvider).value!,
                                  isOpenTime: false,
                                ),
                                amountPaid: 0,
                                phoneNumbers: [],
                              );
                            },
                          ),
                          // ---------- END TEST SECTION ----------
                          ElevatedButton.icon(
                            icon: const Icon(Icons.history_edu, size: 24),
                            label: Text("Reports & History",
                                style: AppTextStyles.primaryButtonTextStyle),
                            onPressed: () async {
                              final dates = await showDialog<List<DateTime?>>(
                                context: context,
                                builder: (context) =>
                                    const DateSelectionDialog(),
                              );

                              if (context.mounted &&
                                  dates != null &&
                                  dates.isNotEmpty) {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => StatsScreen(
                                        dates.whereType<DateTime>().toList())));
                              }
                            },
                            style: AppButtonStyles.primaryButton,
                          ),
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
                      padding: const EdgeInsets.all(16.0),
                      child: CurrentPlayersTable(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // -----------------------------------------------------
          // Right side - 35% of screen width
          // -----------------------------------------------------
          Container(
            width: MediaQuery.of(context).size.width * 0.35,
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            color: mainBlue,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 16, // Horizontal spacing between buttons
                        runSpacing:
                            16, // Vertical spacing between rows if buttons wrap
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart, size: 24),
                            label: Text("Edit Product Inventory",
                                style: AppTextStyles.primaryButtonTextStyle),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AddProductScreen(),
                                ),
                              );
                            },
                            style: AppButtonStyles.primaryButton,
                          ),
                          ElevatedButton.icon(
                              label: Text("Subscriptions",
                                  style: AppTextStyles.primaryButtonTextStyle),
                              icon: const Icon(Icons.hotel_class, size: 24),
                              style: AppButtonStyles.primaryButton,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SubscriptionsScreen(),
                                  ),
                                );
                              })
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Column(
                    children: [
                      // Products table
                      Expanded(
                        flex: 4,
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ProductsTable(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stats section
                      Expanded(
                        flex: 6,
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: RevenueCard([DateTime.now()]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Notes section
                      Expanded(
                        flex: 6,
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            // child: Notes(),
                            child: DebtsCard(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
