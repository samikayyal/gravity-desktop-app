// ignore: unused_import
import 'dart:developer';

extension DateTimeFormatting on DateTime {
  String toYYYYMMDD() {
    return toLocal().toString().split(' ')[0];
  }
}

DateTime getLastSaturday({required DateTime fromDate}) {
  // DateTime.saturday is 6 and DateTime.sunday is 7.
  // The formula `(date.weekday - DateTime.saturday + 7) % 7` ensures we get a
  // positive number of days to subtract, correctly handling the week's wrap-around.

  // If today is Sunday (7): (7 - 6 + 7) % 7 = 8 % 7 = 1 day to subtract.
  // If today is Saturday (6): (6 - 6 + 7) % 7 = 7 % 7 = 0 days to subtract.
  // If today is Monday (1): (1 - 6 + 7) % 7 = 2 % 7 = 2 days to subtract.
  final int daysToSubtract = (fromDate.weekday - DateTime.saturday + 7) % 7;

  // Subtract the calculated days to get the date of the last Saturday
  DateTime lastSaturday = fromDate.subtract(Duration(days: daysToSubtract));
  return DateTime(
    lastSaturday.year,
    lastSaturday.month,
    lastSaturday.day,
  );
}

List<DateTime> getBusinessWeekDates({
  required DateTime lastDate,
}) {
  final lastSaturday = getLastSaturday(
    fromDate: lastDate,
  );
  log("last date: $lastDate, last saturday: $lastSaturday");

  // If today is Saturday, select only that date.
  if (lastDate.toYYYYMMDD() == lastSaturday.toYYYYMMDD()) {
    return [lastSaturday];
  }
  final startDate = lastSaturday;
  final endDate = lastDate;
  return List.generate(
    endDate.difference(startDate).inDays + 1,
    (index) => startDate.add(Duration(days: index)),
  );
}
