// ignore_for_file: unused_import

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';
import 'package:gravity_desktop_app/home.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // set up window options
  WindowOptions windowOptions = WindowOptions(
    center: true,
    skipTaskbar: false, // this will show the app in the taskbar
    titleBarStyle: TitleBarStyle.hidden, // this will hide the title bar
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // // --- NEW LOGIC FOR TESTING ---

    // // Only run this code if we are in DEBUG mode
    // if (kDebugMode) {
    //   // Hardcode the position for your second monitor.
    //   // Replace 1920 with the width of your primary monitor.
    //   await windowManager.setPosition(const Offset(-1080, 0));
    // }

    // // --- END OF NEW LOGIC ---

    await windowManager.show();
    await windowManager.focus();

    // set fullscreen
    await windowManager.setFullScreen(true);
    // set unable to close
    await windowManager.setPreventClose(true);
  });

  sqfliteFfiInit(); // Initialize sqflite with FFI support
  databaseFactory = databaseFactoryFfi; // Use FFI database factory

  runApp(ProviderScope(child: GravityApp()));
}

Future<void> closeApp() async {
  final container = ProviderScope.containerOf(
    WidgetsBinding.instance.rootElement!,
    listen: false,
  );
  final db = await container.read(databaseProvider).database;
  await db.close();

  await windowManager.close();
}

class GravityApp extends StatelessWidget {
  const GravityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class TestScreen extends ConsumerStatefulWidget {
  const TestScreen({super.key});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> {
  final hoursReservedController = TextEditingController();
  final minutesReservedController = TextEditingController();
  final hourController = TextEditingController();
  final minuteController = TextEditingController();
  int price = 0;

  void _calculateFee(Map<TimeSlice, int> prices) {
    final hoursReserved = int.tryParse(hoursReservedController.text) ?? 0;
    final minutesReserved = int.tryParse(minutesReservedController.text) ?? 0;
    final hours = int.tryParse(hourController.text) ?? 0;
    final minutes = int.tryParse(minuteController.text) ?? 0;

    // Calculate the fee based on the hours and minutes
    setState(() {
      price = calculateFinalFee(
          timeReserved:
              Duration(hours: hoursReserved, minutes: minutesReserved),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: Duration(hours: hours, minutes: minutes),
          prices: prices);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: ref.watch(pricesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => const Center(
                child: Text('Error loading prices. Please try again later.')),
            data: (prices) {
              return Center(
                child: FractionallySizedBox(
                  heightFactor: 0.5,
                  widthFactor: 0.5,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                            controller: hoursReservedController,
                            decoration: const InputDecoration(
                              labelText: 'Hours Reserved',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => _calculateFee(prices),
                          )),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: minutesReservedController,
                              decoration: const InputDecoration(
                                labelText: 'Minutes Reserved',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _calculateFee(prices),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: hourController,
                              decoration: const InputDecoration(
                                labelText: 'Hours',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _calculateFee(prices),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: minuteController,
                              decoration: const InputDecoration(
                                labelText: 'Minutes',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _calculateFee(prices),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                      Text(
                        price.toString(),
                        style: AppTextStyles.pageTitleStyle,
                      ),
                    ],
                  ),
                ),
              );
            }));
  }
}
