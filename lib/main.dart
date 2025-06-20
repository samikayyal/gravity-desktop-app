import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/screens/home.dart';
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
    // --- NEW LOGIC FOR TESTING ---

    // Only run this code if we are in DEBUG mode
    if (kDebugMode) {
      // Hardcode the position for your second monitor.
      // Replace 1920 with the width of your primary monitor.
      await windowManager.setPosition(const Offset(-1080, 0));
    }

    // --- END OF NEW LOGIC ---

    await windowManager.show();
    await windowManager.focus();

    // set fullscreen
    await windowManager.setFullScreen(true);
    // set unable to close
    await windowManager.setPreventClose(true);
  });

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravity Desktop App',
      home: HomeScreen(),
    );
  }
}
