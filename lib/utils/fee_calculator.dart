import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/utils/constants.dart';

int calculatePreCheckInFee({
  required int hoursReserved,
  required int minutesReserved,
  required Map<TimeSlice, int> prices,
  required bool isOpenTime,
}) {
  // Open time has no fee
  if (isOpenTime) return 0;
  if (hoursReserved == 0 && minutesReserved == 0) {
    return 0; // No time reserved, no fee
  }

  int total = 0;
  // If there is at least 1 hour, charge first hour at base price
  if (hoursReserved > 0) {
    total += prices[TimeSlice.hour]!;
    if (hoursReserved > 1) {
      total += (hoursReserved - 1) * (prices[TimeSlice.additionalHour]!);
    }
    // If there is a half hour, charge it at additional half hour price
    if (minutesReserved == 30) {
      total += prices[TimeSlice.additionalHalfHour]!;
    }
  } else if (minutesReserved == 30) {
    // No full hour, charge first half hour at base price
    total += prices[TimeSlice.halfHour]!;
  }
  return total;
}

int calculateFinalFee({
  required Duration timeSpent,
  required Map<TimeSlice, int> prices,
  Map<int, int>? productsBought,
  List<Product>? allProducts,
}) {
  if (timeSpent.isNegative || timeSpent.inMinutes <= 0) {
    return 0;
  }

  // --- Leeway Logic ---
  final totalMinutes = timeSpent.inMinutes;
  final fullBlocks = totalMinutes ~/ 30;
  final remainderMinutes = totalMinutes % 30;

  int totalHalfHourBlocks;
  if (remainderMinutes > leewayMinutes) {
    totalHalfHourBlocks = fullBlocks + 1; // Over leeway, charge for next block
  } else {
    totalHalfHourBlocks =
        fullBlocks; // Within leeway, only charge for full blocks
  }

  // --- Fee Calculation Logic
  if (totalHalfHourBlocks == 0) return prices[TimeSlice.halfHour]!;

  int total = 0;

  // Case 1: Time spent is 1 hour or more (2+ half-hour blocks)
  if (totalHalfHourBlocks >= 2) {
    // Always charge the base price for the very first hour.
    total += prices[TimeSlice.hour]!;

    // Calculate remaining time beyond the first hour.
    int remainingHalfHourBlocks = totalHalfHourBlocks - 2;

    // Charge for any additional full hours.
    int additionalFullHours = remainingHalfHourBlocks ~/ 2;
    total += additionalFullHours * prices[TimeSlice.additionalHour]!;

    // If there's a final half-hour left, charge for it.
    if (remainingHalfHourBlocks % 2 == 1) {
      total += prices[TimeSlice.additionalHalfHour]!;
    }
  }
  // Case 2: Time spent is less than 1 hour (exactly 1 half-hour block)
  else {
    total += prices[TimeSlice.halfHour]!;
  }

  // --- Product Fees Logic ---
  if (productsBought != null && allProducts == null) {
    throw ArgumentError(
      'All products must be provided if products bought are specified.',
    );
  }

  if (productsBought != null && productsBought.isNotEmpty) {
    for (final entry in productsBought.entries) {
      final productId = entry.key;
      final quantity = entry.value;

      // Find the product by ID
      final product = allProducts!.firstWhere(
        (p) => p.id == productId,
        orElse: () =>
            throw ArgumentError('Product with ID $productId not found.'),
      );

      // Add the product fee to the total
      total += product.price * quantity;
    }
  }
  return total;
}

int calculateSubscriptionFee(
    {required int discount,
    required int hours,
    required Map<TimeSlice, int> prices}) {
  if (hours <= 0) return 0;
  if (discount < 0 || discount > 100) {
    throw ArgumentError('Discount must be between 0 and 100.');
  }
  if (prices.isEmpty) throw ArgumentError('Prices must not be empty.');

  // Calculate the total fee for the subscription duration
  final double rawFee =
      (hours * prices[TimeSlice.hour]!) * (100 - discount) / 100;

  // Round up to the nearest 10000
  return ((rawFee / 10000).ceil()) * 10000;
}
