extension DateTimeFormatting on DateTime {
  String toYYYYMMDD() {
    return toLocal().toString().split(' ')[0];
  }
}

DateTime getLastSaturday(
    {required DateTime fromDate, bool oneBeforeLast = false}) {
  // DateTime.saturday is 6 and DateTime.sunday is 7.
  // The formula `(date.weekday - DateTime.saturday + 7) % 7` ensures we get a
  // positive number of days to subtract, correctly handling the week's wrap-around.

  // If today is Sunday (7): (7 - 6 + 7) % 7 = 8 % 7 = 1 day to subtract.
  // If today is Saturday (6): (6 - 6 + 7) % 7 = 7 % 7 = 0 days to subtract.
  // If today is Monday (1): (1 - 6 + 7) % 7 = 2 % 7 = 2 days to subtract.
  final int daysToSubtract = (fromDate.weekday - DateTime.saturday + 7) % 7;

  // Subtract the calculated days to get the date of the last Saturday
  DateTime lastSaturday = fromDate.subtract(Duration(days: daysToSubtract));

  if (oneBeforeLast) {
    // If we want the Saturday before the last one, subtract 7 days
    lastSaturday = lastSaturday.subtract(const Duration(days: 7));
  }
  return DateTime(
    lastSaturday.year,
    lastSaturday.month,
    lastSaturday.day,
  );
}
