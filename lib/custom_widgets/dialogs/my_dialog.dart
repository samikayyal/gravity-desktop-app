import 'package:flutter/material.dart';

class MyDialog extends StatelessWidget {
  final Widget child;
  final double? width;

  const MyDialog({
    super.key,
    required this.child,
    this.width = 480.0,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // insetPadding:
      //     const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width ?? 480.0,
          ),
          child: Container(
            // padding: const EdgeInsets.all(24.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
