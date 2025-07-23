extension DateTimeFormatting on DateTime {
  String toYYYYMMDD() {
    return toLocal().toString().split(' ')[0];
  }
}