import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/utils/fee_calculator.dart';

void main() {
  group('Fee Calculator Tests', () {
    // Test data
    late Map<TimeSlice, int> testPrices;
    late List<Product> testProducts;

    setUp(() {
      testPrices = {
        TimeSlice.hour: 95000,
        TimeSlice.additionalHour: 70000,
        TimeSlice.halfHour: 75000,
        TimeSlice.additionalHalfHour: 45000,
      };

      testProducts = [
        Product(id: 1, name: 'Socks', price: 25000, effectiveStock: 100),
        Product(id: 2, name: 'Water', price: 7000, effectiveStock: 100),
      ];
    });

    group('calculatePreCheckInFee', () {
      test('returns 0 for open time', () {
        final fee = calculatePreCheckInFee(
          hoursReserved: 2,
          minutesReserved: 30,
          timeExtendedMinutes: 0,
          prices: testPrices,
          isOpenTime: true,
        );
        expect(fee, 0);
      });

      test('returns 0 for no time reserved', () {
        final fee = calculatePreCheckInFee(
          hoursReserved: 0,
          minutesReserved: 0,
          timeExtendedMinutes: 0,
          prices: testPrices,
          isOpenTime: false,
        );
        expect(fee, 0);
      });

      test('calculates correct fee for 1 hour', () {
        final fee = calculatePreCheckInFee(
          hoursReserved: 1,
          minutesReserved: 0,
          timeExtendedMinutes: 0,
          prices: testPrices,
          isOpenTime: false,
        );
        expect(fee, testPrices[TimeSlice.hour]); // First hour
      });

      test('calculates correct fee for 2 hours', () {
        final fee = calculatePreCheckInFee(
          hoursReserved: 2,
          minutesReserved: 0,
          timeExtendedMinutes: 0,
          prices: testPrices,
          isOpenTime: false,
        );
        expect(
            fee,
            testPrices[TimeSlice.hour]! +
                testPrices[TimeSlice.additionalHour]!);
      });

      test('calculates correct fee for 30 minutes', () {
        final fee = calculatePreCheckInFee(
          hoursReserved: 0,
          minutesReserved: 30,
          timeExtendedMinutes: 0,
          prices: testPrices,
          isOpenTime: false,
        );
        expect(fee, testPrices[TimeSlice.halfHour]); // Half hour
      });

      test('calculates correct fee for 1 hour 30 minutes', () {
        final fee = calculatePreCheckInFee(
          hoursReserved: 1,
          minutesReserved: 30,
          timeExtendedMinutes: 0,
          prices: testPrices,
          isOpenTime: false,
        );
        expect(
            fee,
            testPrices[TimeSlice.hour]! +
                testPrices[TimeSlice.additionalHalfHour]!);
      });

      test('includes time extension in calculation', () {
        final fee = calculatePreCheckInFee(
          hoursReserved: 1,
          minutesReserved: 0,
          timeExtendedMinutes: 30,
          prices: testPrices,
          isOpenTime: false,
        );
        expect(
            fee,
            testPrices[TimeSlice.hour]! +
                testPrices[TimeSlice.additionalHalfHour]!);
      });
    });

    group('calculateFinalFee', () {
      test('returns 0 for negative time spent', () {
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 1),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(minutes: -10),
          prices: testPrices,
        );
        expect(fee, 0);
      });

      test('charges for actual time when less than reserved (open time)', () {
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 2),
          isOpenTime: true,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(hours: 1),
          prices: testPrices,
        );
        expect(fee, testPrices[TimeSlice.hour]!);
      });

      test('charges correctly when staying longer than reserved', () {
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 1),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(hours: 1, minutes: 30),
          prices: testPrices,
        );
        expect(
            fee,
            testPrices[TimeSlice.hour]! +
                testPrices[TimeSlice.additionalHalfHour]!);
      });

      test('applies leeway correctly for additional time', () {
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 1),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(hours: 1, minutes: 10), // Within leeway
          prices: testPrices,
        );
        expect(fee, testPrices[TimeSlice.hour]!);
      });

      test('charges additional time beyond leeway', () {
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 1),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(hours: 1, minutes: 15), // Beyond leeway
          prices: testPrices,
        );
        expect(
            fee,
            testPrices[TimeSlice.hour]! +
                testPrices[TimeSlice.additionalHalfHour]!);
      });

      test('includes product fees when provided', () {
        final productsBought = {1: 2, 2: 1}; // 2 socks, 1 water
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 1),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(hours: 1),
          prices: testPrices,
          productsBought: productsBought,
          allProducts: testProducts,
        );
        expect(
            fee,
            testPrices[TimeSlice.hour]! +
                (2 * testProducts[0].price) + // 2 socks
                (1 * testProducts[1].price)); // 1 water
      });

      test(
          'throws error when products bought without all products being provided',
          () {
        final productsBought = {1: 1};
        expect(
          () => calculateFinalFee(
            timeReserved: const Duration(hours: 1),
            isOpenTime: false,
            timeExtendedMinutes: 0,
            timeSpent: const Duration(hours: 1),
            prices: testPrices,
            productsBought: productsBought,
            // allProducts not provided
          ),
          throwsArgumentError,
        );
      });
    });

    group('calculateProductsFee', () {
      test('calculates correct total for multiple products', () {
        final productsBought = {
          1: 3, // 3 socks
          2: 2, // 2 water
        };
        final fee = calculateProductsFee(
          productsBought: productsBought,
          allProducts: testProducts,
        );
        expect(fee, (3 * testProducts[0].price) + (2 * testProducts[1].price));
      });

      test('returns 0 for empty products', () {
        final fee = calculateProductsFee(
          productsBought: {},
          allProducts: testProducts,
        );
        expect(fee, 0);
      });

      test('throws error for non-existent product', () {
        final productsBought = {999: 1}; // Non-existent product
        expect(
          () => calculateProductsFee(
            productsBought: productsBought,
            allProducts: testProducts,
          ),
          throwsArgumentError,
        );
      });
    });

    group('calculateSubscriptionFee', () {
      test('calculates correct subscription fee with discount', () {
        final fee = calculateSubscriptionFee(
          discount: 45, // 45% discount
          hours: 10,
          prices: testPrices,
        );
        expect(fee, 530000);
      });

      test('returns 0 for 0 hours', () {
        final fee = calculateSubscriptionFee(
          discount: 20,
          hours: 0,
          prices: testPrices,
        );
        expect(fee, 0);
      });

      test('throws error for invalid discount', () {
        expect(
          () => calculateSubscriptionFee(
            discount: -5,
            hours: 10,
            prices: testPrices,
          ),
          throwsArgumentError,
        );

        expect(
          () => calculateSubscriptionFee(
            discount: 105,
            hours: 10,
            prices: testPrices,
          ),
          throwsArgumentError,
        );
      });

      test('throws error for empty prices', () {
        expect(
          () => calculateSubscriptionFee(
            discount: 20,
            hours: 10,
            prices: {},
          ),
          throwsArgumentError,
        );
      });

      test('rounds up to nearest 10000', () {
        final fee = calculateSubscriptionFee(
          discount: 15, // 85% of original
          hours: 1,
          prices: testPrices,
        );
        // 1 * 95000 * 0.85 = 80750, rounded up to 90000
        expect(fee, 90000);
      });
    });

    group('Edge Cases', () {
      test('handles very long durations correctly', () {
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 8),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(hours: 10),
          prices: testPrices,
        );
        final expectedFee = testPrices[TimeSlice.hour]! +
            testPrices[TimeSlice.additionalHour]! * 9;
        expect(fee, expectedFee);
      });

      test('handles zero prices gracefully', () {
        final zeroPrices = {
          TimeSlice.hour: 0,
          TimeSlice.additionalHour: 0,
          TimeSlice.halfHour: 0,
          TimeSlice.additionalHalfHour: 0,
        };
        final fee = calculateFinalFee(
          timeReserved: const Duration(hours: 2),
          isOpenTime: false,
          timeExtendedMinutes: 0,
          timeSpent: const Duration(hours: 3),
          prices: zeroPrices,
        );
        expect(fee, 0);
      });
    });
  });
}
