/// Date comparison utilities.
extension DateTimeExtension on DateTime {
  /// Returns `true` if this date falls on the same calendar day as [other].
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
