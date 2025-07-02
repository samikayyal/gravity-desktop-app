import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';

enum MessageType { success, error, info }

class MyMaterialBanner {
  // Keep the original method for backward compatibility
  static showBanner(BuildContext context,
      {required String message,
      int? durationInSeconds = 3,
      MessageType type = MessageType.info}) {
    Color backgroundColor;
    Icon icon;

    switch (type) {
      case MessageType.success:
        backgroundColor = Colors.green;
        icon = Icon(Icons.check_circle, color: Colors.white);
        break;
      case MessageType.error:
        backgroundColor = Colors.red;
        icon = Icon(Icons.error, color: Colors.white);
        break;
      case MessageType.info:
        backgroundColor = Colors.blue;
        icon = Icon(Icons.info, color: Colors.white);
        break;
    }

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 24), // Space for symmetry with close button
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: AppTextStyles.sectionHeaderStyle
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24), // Space for symmetry
          ],
        ),
        backgroundColor: backgroundColor,
        leading: const SizedBox.shrink(), // Remove default leading
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );

    if (durationInSeconds == null) return;
    Future.delayed(Duration(seconds: durationInSeconds), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  // New floating banner method using Overlay
  static showFloatingBanner(BuildContext context,
      {required String message,
      int? durationInSeconds = 3,
      MessageType type = MessageType.info}) {
    Color backgroundColor;
    Icon icon;

    switch (type) {
      case MessageType.success:
        backgroundColor = Colors.green;
        icon = Icon(Icons.check_circle, color: Colors.white);
        break;
      case MessageType.error:
        backgroundColor = Colors.red;
        icon = Icon(Icons.error, color: Colors.white);
        break;
      case MessageType.info:
        backgroundColor = Colors.blue;
        icon = Icon(Icons.info, color: Colors.white);
        break;
    }

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 90, // Position below app bar
        left: 20,
        right: 20,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(
                    width: 24), // Space for symmetry with close button
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 8),
                      Text(
                        message,
                        style: AppTextStyles.sectionHeaderStyle
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => overlayEntry.remove(),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    if (durationInSeconds != null) {
      Future.delayed(Duration(seconds: durationInSeconds), () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      });
    }
  }
}
