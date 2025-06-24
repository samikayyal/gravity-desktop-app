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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24.0),
        child: IntrinsicWidth(
          child: child,
        ),
      ),
    );
  }
}
