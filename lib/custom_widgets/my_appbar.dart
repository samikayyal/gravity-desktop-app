import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/utils/constants.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppBar({super.key});

  @override
  // its normaly kToolbarHeight which is 56.0
  Size get preferredSize => const Size.fromHeight(66.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      backgroundColor: gravityYellow,
      title: const Text(
        "Gravity",
        style: TextStyle(fontFamily: "Lazy Dog", fontSize: 50),
      ),
    );
  }
}
