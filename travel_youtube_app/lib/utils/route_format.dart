/// Formats a route's total duration/distance for display (route summary
/// cards, trip day cards) -- shared so both stay in sync.
String formatRouteDuration(int? seconds) {
  if (seconds == null) return '-';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '$hours시간 $minutes분';
  return '$minutes분';
}

String formatRouteDistance(int? meters) {
  if (meters == null) return '-';
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
  return '${meters}m';
}
