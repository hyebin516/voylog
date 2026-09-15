/// Formats a trip date as `YYYY.MM.DD`, matching the design's date-range
/// display -- shared between the "새 여행 만들기" picker and the trip detail
/// screen so both stay in sync.
String formatTripDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}
