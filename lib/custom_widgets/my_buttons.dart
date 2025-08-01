import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/utils/constants.dart';

class AppButtonStyles {
  // Primary button style (for important actions)
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.white, // Clean white background
    foregroundColor: mainBlue, // Indigo text
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
    minimumSize: const Size(150, 48), // Bigger target for desktop
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
      side: const BorderSide(color: mainBlue, width: 1.5),
    ),
    elevation: 1,
  );

  // Secondary button style (for less important actions)
  static ButtonStyle secondaryButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xFF607D8B), // Blue-gray
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
    minimumSize: const Size(150, 48), // Bigger target for desktop
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
      side: const BorderSide(color: Color(0xFF607D8B), width: 1.5),
    ),
    elevation: 0,
  );

  // Danger button style (for destructive actions)
  static ButtonStyle dangerButton = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFE53935), // Bold red background
    foregroundColor: Colors.white, // White text for contrast
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
    minimumSize: const Size(150, 48), // Bigger target for desktop
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
      side: const BorderSide(color: Color(0xFFD32F2F), width: 2.0),
    ),
    elevation: 2,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFD32F2F); // Darker red on hover
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFFB71C1C); // Even darker red on press
        }
        return null;
      },
    ),
  );

  // Icon button style with a refined circular shape and subtle hover/splash effect
  static ButtonStyle iconButtonCircle = IconButton.styleFrom(
    backgroundColor: Colors.blueGrey.shade50,
    foregroundColor: Colors.blueGrey.shade700,
    padding: const EdgeInsets.all(10.0),
    shape: const CircleBorder(),
    elevation: 0,
    minimumSize: const Size(35, 35), // Ensure consistent circular dimensions
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.hovered)) {
          return Colors.blueGrey.shade100.withAlpha(200); // Subtle hover color
        }
        if (states.contains(WidgetState.pressed)) {
          return Colors.blueGrey.shade200
              .withAlpha(230); // Splash color on press
        }
        return null;
      },
    ),
    side: WidgetStateProperty.all(
      BorderSide(color: Colors.blueGrey.shade200, width: 1.0),
    ),
  );
}
