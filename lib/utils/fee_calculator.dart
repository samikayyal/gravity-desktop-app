// ignore: unused_import
import 'dart:developer';

import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/screens/add_group.dart';
import 'package:gravity_desktop_app/utils/constants.dart';

int calculatePreCheckInFee({
  required int hoursReserved,
  required int minutesReserved,
  required int timeExtendedMinutes,
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

  // addtional time (extended)
  if (timeExtendedMinutes > 0) {
    final int extendedHours = timeExtendedMinutes ~/ 60;
    final int extendedRemainderMinutes = timeExtendedMinutes % 60;

    if (extendedHours > 0) {
      total += prices[TimeSlice.additionalHour]! * extendedHours;
    }
    if (extendedRemainderMinutes == 30) {
      total += prices[TimeSlice.additionalHalfHour]!;
    }
  }
  return total;
}

int calculateFinalFee({
  required Duration timeReserved,
  required bool isOpenTime,
  required Duration timeSpent,
  required Map<TimeSlice, int> prices,
  required int timeExtendedMinutes,
  Map<int, int>? productsBought,
  List<Product>? allProducts,
}) {
  if (timeSpent.isNegative || timeSpent.inMinutes < 0) {
    return 0;
  }

  // --- Fee Calculation Logic
  int total = 0;

  if (isOpenTime) {
    total += _calculateOpenTimeFee(
      timeSpent: timeSpent,
      prices: prices,
    );
  } else {
    // player stayed less than the time they reserved, then charge them
    // based on the time they spent
    if (timeSpent < timeReserved) {
      total += _calculateOpenTimeFee(timeSpent: timeSpent, prices: prices);
    } else {
      // player stayed more than the time they reserved, then charge them
      // the full fee for the reserved time + any additional time
      total += calculatePreCheckInFee(
        hoursReserved: timeReserved.inHours,
        minutesReserved: timeReserved.inMinutes % 60,
        timeExtendedMinutes: 0,
        prices: prices,
        isOpenTime: isOpenTime,
      );

      log("Total here: $total");

      // If the player stayed more than the reserved time, charge for the
      // additional time spent
      if (timeSpent > timeReserved) {
        final totalAdditionalMinutes =
            timeSpent.inMinutes - timeReserved.inMinutes;
        final fullBlocks =
            totalAdditionalMinutes ~/ 30; // Full half-hour blocks
        final additionalRemainderMinutes = totalAdditionalMinutes % 30;

        int additionalHalfHourBlocks;
        if (additionalRemainderMinutes > leewayMinutes) {
          additionalHalfHourBlocks =
              fullBlocks + 1; // Over leeway, charge for next block
        } else {
          additionalHalfHourBlocks =
              fullBlocks; // Within leeway, only charge for full blocks
        }

        // Calculate the fee for additional time spent
        final int additionalHourBlocks = additionalHalfHourBlocks ~/ 2;
        final int additionalHalfHourBlocksRemainder =
            additionalHalfHourBlocks % 2;
        total += (additionalHourBlocks * prices[TimeSlice.additionalHour]!) +
            (additionalHalfHourBlocksRemainder *
                prices[TimeSlice.additionalHalfHour]!);
      }
    }
  }

  // --- Product Fees Logic ---
  if (productsBought != null && allProducts == null) {
    throw ArgumentError(
      'All products must be provided if products bought are specified.',
    );
  }

  if (productsBought != null && productsBought.isNotEmpty) {
    total += calculateProductsFee(
        productsBought: productsBought, allProducts: allProducts!);
  }

  return total;
}

int calculateProductsFee({
  required Map<int, int> productsBought,
  required List<Product> allProducts,
}) {
  int total = 0;
  for (final entry in productsBought.entries) {
    final productId = entry.key;
    final quantity = entry.value;

    // Find the product by ID
    final product = allProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () =>
          throw ArgumentError('Product with ID $productId not found.'),
    );

    // Add the product fee to the total
    total += product.price * quantity;
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

int calculateGroupPlayerFee({
  required GroupPlayer player,
  required int timeReservedMinutes,
  required int timeExtendedMinutes,
  required bool isOpenTime,
  required Map<TimeSlice, int> prices,
  required List<Product> allProducts,
}) {
  int fee = calculatePreCheckInFee(
      hoursReserved: timeReservedMinutes ~/ 60,
      minutesReserved: timeReservedMinutes % 60,
      timeExtendedMinutes: timeExtendedMinutes,
      prices: prices,
      isOpenTime: isOpenTime);

  for (var entry in player.productsCart.entries) {
    final product = allProducts.firstWhere((p) => p.id == entry.key);
    fee += entry.value * product.price;
  }

  return fee;
}

int _calculateOpenTimeFee(
    {required Duration timeSpent, required Map<TimeSlice, int> prices}) {
  final fullBlocks = timeSpent.inMinutes ~/ 30;
  final remainderMinutes = timeSpent.inMinutes % 30;

  int totalHalfHourBlocks;
  if (remainderMinutes > leewayMinutes) {
    totalHalfHourBlocks = fullBlocks + 1; // Over leeway, charge for next block
  } else {
    totalHalfHourBlocks =
        fullBlocks; // Within leeway, only charge for full blocks
  }

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

  return total;
}
