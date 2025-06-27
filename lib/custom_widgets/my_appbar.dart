import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/providers/time_provider.dart';
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
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 20.0),
          child: ClockWidget(),
        ),
      ],
    );
  }
}

class ClockWidget extends ConsumerWidget {
  const ClockWidget({super.key});

  String _formatDateTime(DateTime dateTime) {
    // format to h:mm:ss a
    final hour = (dateTime.hour % 12 == 0) ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(timeProvider);

    return time.when(
      data: (value) {
        return Center(
          child: Text(
            _formatDateTime(value),
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
