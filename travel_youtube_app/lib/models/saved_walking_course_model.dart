import 'itinerary_model.dart';

class SavedWalkingCourseModel {
  final String savedCourseId;
  final String region;
  final String routeType; // 'roundTrip' | 'hotelToHotel'
  final String transportMode;
  final int? totalDistanceM;
  final int? totalDurationSec;
  final List<RoutePointModel> routeData;
  final DateTime createdAt;

  const SavedWalkingCourseModel({
    required this.savedCourseId,
    required this.region,
    required this.routeType,
    required this.transportMode,
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.routeData,
    required this.createdAt,
  });

  bool get isRoundTrip => routeType == 'roundTrip';

  /// A bookmark-folder route: from one place to another, no hotel -- so
  /// neither the 왕복 nor the 호텔 → 호텔 label applies.
  bool get isPlaceToPlace => routeType == 'placeToPlace';

  factory SavedWalkingCourseModel.fromJson(Map<String, dynamic> json) {
    return SavedWalkingCourseModel(
      savedCourseId: json['savedCourseId'] as String,
      region: json['region'] as String,
      routeType: json['routeType'] as String,
      transportMode: json['transportMode'] as String,
      totalDistanceM: json['totalDistanceM'] as int?,
      totalDurationSec: json['totalDurationSec'] as int?,
      routeData: (json['routeData'] as List<dynamic>? ?? [])
          .map((e) => RoutePointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
