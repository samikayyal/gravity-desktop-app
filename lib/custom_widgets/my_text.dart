import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gravity_desktop_app/utils/constants.dart';

// Text styles for consistent use throughout the app
class AppTextStyles {
  // Style for main page titles
  static TextStyle pageTitleStyle = GoogleFonts.notoSans(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF37474F), // A dark, professional blue-grey
  );

  // Style for section headers
  static TextStyle sectionHeaderStyle = GoogleFonts.notoSans(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: mainBlue,
  );

  // Style for regular text
  static TextStyle regularTextStyle = GoogleFonts.notoSans(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: const Color(0xFF424242),
  );

  // Style for subtitle text
  static TextStyle subtitleTextStyle = GoogleFonts.notoSans(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF757575),
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
    color: mainBlue,
  );

  // Style for table cells
  static TextStyle tableCellStyle = GoogleFonts.notoSans(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: const Color(0xFF424242),
  );

  // Style for primary button text
  static TextStyle primaryButtonTextStyle = GoogleFonts.notoSans(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: mainBlue,
  );

  static TextStyle secondaryButtonTextStyle = GoogleFonts.notoSans(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF757575),
  );

  // Style for danger button text
  static TextStyle dangerButtonTextStyle = GoogleFonts.notoSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
