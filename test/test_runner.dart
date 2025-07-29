import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'utils/fee_calculator_test.dart' as fee_calculator_tests;
import 'utils/general_test.dart' as general_tests;
import 'custom_widgets/my_text_test.dart' as text_style_tests;

void main() {
  group('Gravity Desktop App - Complete Test Suite', () {
    group('🧮 Utils Tests', () {
      group('Fee Calculator', fee_calculator_tests.main);
      group('General Utilities', general_tests.main);
    });

    group('🎨 Widget Tests', () {
      group('Text Styles', text_style_tests.main);
    });
  });
}
