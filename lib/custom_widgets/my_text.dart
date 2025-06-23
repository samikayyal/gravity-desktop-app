import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Text styles for consistent use throughout the app
class AppTextStyles {
  // Style for section headers
  static TextStyle sectionHeaderStyle = GoogleFonts.notoSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF3949AB),
  );

  // Style for regular text
  static TextStyle regularTextStyle = GoogleFonts.notoSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: const Color(0xFF424242),
  );

  // Style for amount values
  static TextStyle amountTextStyle = GoogleFonts.notoSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF424242),
  );

  // Style for highlighted values
  static TextStyle highlightedTextStyle = GoogleFonts.notoSans(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF3949AB),
  );
}

class PrimaryButtonText extends StatelessWidget {
  final String text;
  const PrimaryButtonText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: GoogleFonts.notoSans().fontFamily),
    );
  }
}
