import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'utils/fee_calculator_test.dart' as fee_calculator_tests;
import 'utils/general_test.dart' as general_tests;
import 'providers/check_in_player_test.dart' as check_in_player_tests;
import 'providers/check_out_player_test.dart' as check_out_player_tests;

void main() {
  group('Gravity Desktop App - Complete Test Suite', () {
    group('🧮 Utils Tests', () {
      group('Fee Calculator', fee_calculator_tests.main);
      group('General Utilities', general_tests.main);
    });

    group('Database Related Tests', () {
      group('Check-In Tests', check_in_player_tests.main);
      group('Check-Out Tests', check_out_player_tests.main);
    });
  });
}
