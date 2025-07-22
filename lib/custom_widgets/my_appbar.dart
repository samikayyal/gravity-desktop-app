// ignore: unused_import
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/time_provider.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isHomeScreen;
  const MyAppBar({super.key, this.isHomeScreen = false});

  @override
  // its normaly kToolbarHeight which is 56.0
  Size get preferredSize => const Size.fromHeight(66.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      backgroundColor: gravityYellow,
      leadingWidth: isHomeScreen ? 200 : null,
      leading: isHomeScreen
          ? Consumer(
              builder: (context, ref, child) {
                final int playerCount =
                    ref.watch(currentPlayersProvider).hasValue
                        ? ref.watch(currentPlayersProvider).value!.length
                        : 0;
                return Center(
                  child: Text(
                    "Players Inside: $playerCount",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: AppTextStyles.sectionHeaderStyle.copyWith(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                  ),
                );
              },
            )
          : null,
      title: const Text(
        "Gravity",
        style: TextStyle(fontFamily: "Lazy Dog", fontSize: 50),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 20.0),
          child: ClockWidget(),
        ),
        if (isHomeScreen)
          Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: TextButton.icon(
              onPressed: () async {
                await windowManager.destroy();
              },
              label: Text(
                "Close",
                style: AppTextStyles.sectionHeaderStyle
                    .copyWith(color: Colors.black),
              ),
              icon: Icon(Icons.close, size: 22, color: Colors.black),
            ),
          ),
      ],
    );
  }
}

class ClockWidget extends ConsumerWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(timeProvider);

    return time.when(
      data: (value) {
        return Center(
          child: Text(
            '${DateFormat('dd/MM/yyyy').format(value)} | ${DateFormat('hh:mm a').format(value)}',
            style:
                AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.black),
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) => const Text('Error'),
    );
  }
}
