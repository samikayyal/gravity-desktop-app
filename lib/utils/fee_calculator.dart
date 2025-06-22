import 'package:gravity_desktop_app/database/database.dart';

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
