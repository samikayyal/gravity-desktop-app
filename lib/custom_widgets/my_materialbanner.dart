import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';

enum MessageType { success, error, info }

class MyMaterialBanner {
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
        content: Text(
          message,
          style: AppTextStyles.sectionHeaderStyle.copyWith(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        leading: icon,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: Text('Dismiss',
                style: AppTextStyles.secondaryButtonTextStyle
                    .copyWith(color: Colors.white)),
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
}
