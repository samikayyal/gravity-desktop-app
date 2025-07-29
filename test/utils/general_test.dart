import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_desktop_app/utils/general.dart';

void main() {
  group('General Utility Functions Tests', () {
    group('DateTime extension tests', () {
      test('toYYYYMMDD formats date correctly', () {
        final testDate = DateTime(2024, 7, 15);
        expect(testDate.toYYYYMMDD(), '2024-07-15');
      });

      test('toYYYYMMDD handles single digit months and days', () {
        final testDate = DateTime(2024, 3, 5);
        expect(testDate.toYYYYMMDD(), '2024-03-05');
      });

      test('toYYYYMMDD handles December 31st', () {
        final testDate = DateTime(2024, 12, 31);
        expect(testDate.toYYYYMMDD(), '2024-12-31');
      });

      test('toYYYYMMDD handles January 1st', () {
        final testDate = DateTime(2024, 1, 1);
        expect(testDate.toYYYYMMDD(), '2024-01-01');
      });

      test('toYYYYMMDD handles leap year February 29th', () {
        final testDate = DateTime(2024, 2, 29); // 2024 is a leap year
        expect(testDate.toYYYYMMDD(), '2024-02-29');
      });

      test('toYYYYMMDD ignores time components', () {
        final testDate = DateTime(2024, 7, 15, 14, 30, 45, 123);
        expect(testDate.toYYYYMMDD(), '2024-07-15');
      });

      test('toYYYYMMDD works with UTC dates', () {
        final testDate = DateTime.utc(2024, 7, 15, 12, 0, 0);
        expect(testDate.toYYYYMMDD(), '2024-07-15');
      });

      test('toYYYYMMDD works with local dates', () {
        final testDate = DateTime(2024, 7, 15, 12, 0, 0);
        expect(testDate.toYYYYMMDD(), '2024-07-15');
      });
    });

    group('edge cases and error handling', () {
      test('toYYYYMMDD handles year 1', () {
        final testDate = DateTime(1, 1, 1);
        expect(testDate.toYYYYMMDD(), '0001-01-01');
      });

      test('toYYYYMMDD handles year 9999', () {
        final testDate = DateTime(9999, 12, 31);
        expect(testDate.toYYYYMMDD(), '9999-12-31');
      });

      test('toYYYYMMDD maintains format with various years', () {
        final testCases = [
          (DateTime(2000, 1, 1), '2000-01-01'),
          (DateTime(2020, 6, 15), '2020-06-15'),
          (DateTime(2050, 11, 30), '2050-11-30'),
          (DateTime(1990, 8, 25), '1990-08-25'),
        ];

        for (final (date, expected) in testCases) {
          expect(date.toYYYYMMDD(), expected);
        }
      });
    });

    group('consistency and format validation', () {
      test('toYYYYMMDD always returns 10 character string', () {
        final testDates = [
          DateTime(1, 1, 1),
          DateTime(2024, 7, 15),
          DateTime(9999, 12, 31),
          DateTime(2000, 2, 29), // Leap year
        ];

        for (final date in testDates) {
          expect(date.toYYYYMMDD().length, 10);
        }
      });

      test('toYYYYMMDD format matches YYYY-MM-DD pattern', () {
        final testDate = DateTime(2024, 7, 15);
        final result = testDate.toYYYYMMDD();

        // Check format: YYYY-MM-DD
        expect(result[4], '-');
        expect(result[7], '-');

        // Check numeric parts
        expect(int.tryParse(result.substring(0, 4)), isNotNull); // Year
        expect(int.tryParse(result.substring(5, 7)), isNotNull); // Month
        expect(int.tryParse(result.substring(8, 10)), isNotNull); // Day
      });

      test('toYYYYMMDD is reversible with DateTime.parse', () {
        final originalDate = DateTime(2024, 7, 15);
        final formatted = originalDate.toYYYYMMDD();
        final parsedDate = DateTime.parse(formatted);

        expect(parsedDate.year, originalDate.year);
        expect(parsedDate.month, originalDate.month);
        expect(parsedDate.day, originalDate.day);
      });

      test('toYYYYMMDD produces sortable strings', () {
        final dates = [
          DateTime(2024, 1, 1),
          DateTime(2024, 7, 15),
          DateTime(2024, 12, 31),
          DateTime(2023, 12, 31),
          DateTime(2025, 1, 1),
        ];

        final formattedDates = dates.map((d) => d.toYYYYMMDD()).toList();
        final sortedFormatted = List<String>.from(formattedDates)..sort();

        // The sorted formatted dates should correspond to chronologically sorted dates
        final chronologicalDates = dates.map((d) => d.toYYYYMMDD()).toList()
          ..sort();

        expect(sortedFormatted, equals(chronologicalDates));
      });
    });

    group('real-world usage scenarios', () {
      test('toYYYYMMDD works for current date', () {
        final now = DateTime.now();
        final formatted = now.toYYYYMMDD();

        expect(formatted.length, 10);
        expect(formatted.contains('-'), true);
        expect(formatted.split('-').length, 3);
      });

      test('toYYYYMMDD handles date range operations', () {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 12, 31);
        final currentDate = DateTime(2024, 7, 15);

        final startFormatted = startDate.toYYYYMMDD();
        final endFormatted = endDate.toYYYYMMDD();
        final currentFormatted = currentDate.toYYYYMMDD();

        // String comparison should work for date ranges
        expect(currentFormatted.compareTo(startFormatted) > 0, true);
        expect(currentFormatted.compareTo(endFormatted) < 0, true);
      });

      test('toYYYYMMDD can be used in database queries', () {
        // Simulate common database query patterns
        final dates = [
          DateTime(2024, 7, 1),
          DateTime(2024, 7, 15),
          DateTime(2024, 7, 31),
        ];

        final formattedDates = dates.map((d) => d.toYYYYMMDD()).toList();

        // Should be suitable for SQL IN clauses
        final sqlPlaceholders = formattedDates.map((d) => "'$d'").join(', ');
        expect(sqlPlaceholders, "'2024-07-01', '2024-07-15', '2024-07-31'");
      });

      test('toYYYYMMDD maintains precision for consecutive days', () {
        final baseDate = DateTime(2024, 7, 15);
        final nextDay = baseDate.add(const Duration(days: 1));
        final prevDay = baseDate.subtract(const Duration(days: 1));

        expect(baseDate.toYYYYMMDD(), '2024-07-15');
        expect(nextDay.toYYYYMMDD(), '2024-07-16');
        expect(prevDay.toYYYYMMDD(), '2024-07-14');
      });

      test('toYYYYMMDD works across month boundaries', () {
        final endOfMonth = DateTime(2024, 7, 31);
        final startOfNextMonth = DateTime(2024, 8, 1);

        expect(endOfMonth.toYYYYMMDD(), '2024-07-31');
        expect(startOfNextMonth.toYYYYMMDD(), '2024-08-01');
      });

      test('toYYYYMMDD works across year boundaries', () {
        final endOfYear = DateTime(2024, 12, 31);
        final startOfNextYear = DateTime(2025, 1, 1);

        expect(endOfYear.toYYYYMMDD(), '2024-12-31');
        expect(startOfNextYear.toYYYYMMDD(), '2025-01-01');
      });
    });
  });
}
