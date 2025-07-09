import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final controller = TextEditingController();
  int price = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: ref.watch(pricesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => const Center(
                child: Text('Error loading prices. Please try again later.')),
            data: (prices) {
              return Column(
                children: [
                  TextField(
                    controller: controller,
                    onChanged: (value) {
                      setState(() {
                        price = calculateSubscriptionFee(
                            discount: 45,
                            hours: int.parse(value),
                            prices: prices);
                      });
                    },
                  ),
                  Text(price.toString()),
                ],
              );
            }));
  }
}
