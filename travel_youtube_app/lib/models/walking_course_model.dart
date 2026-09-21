import 'itinerary_model.dart';
import 'nearby_recommendation_model.dart';

/// The ordered walking route itself -- shaped like `ItineraryModel` but
/// without `itineraryId`/`tripId`/`dayNumber`, since a generated course is
/// an ephemeral discovery result, not (yet) a saved itinerary.
class WalkingCourseRouteModel {
  final String routeType; // 'roundTrip' | 'hotelToHotel'
  final String transportMode;
  final int totalDistanceM;
  final int totalDurationSec;
  final List<RoutePointModel> routeData;

  const WalkingCourseRouteModel({
    required this.routeType,
    required this.transportMode,
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.routeData,
  });

  bool get isRoundTrip => routeType == 'roundTrip';

  /// A bookmark-folder route: from one place to another, no hotel.
  bool get isPlaceToPlace => routeType == 'placeToPlace';

  /// Some legs walked, some by bus.
  bool get isMixedTransport => transportMode == 'mixed';

  factory WalkingCourseRouteModel.fromJson(Map<String, dynamic> json) {
    return WalkingCourseRouteModel(
      routeType: json['routeType'] as String,
      transportMode: json['transportMode'] as String,
      totalDistanceM: json['totalDistanceM'] as int,
      totalDurationSec: json['totalDurationSec'] as int,
      routeData: (json['optimizedRoute'] as List<dynamic>? ?? [])
          .map((e) => RoutePointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WalkingCourseModel {
  /// Null when fewer than 2 mutually-walkable places could be found for
  /// the region -- not an error, just "not enough nearby yet".
  final WalkingCourseRouteModel? course;
  final List<NearbyRecommendationModel> recommendations;

  const WalkingCourseModel({required this.course, required this.recommendations});

  factory WalkingCourseModel.fromJson(Map<String, dynamic> json) {
    final courseJson = json['course'] as Map<String, dynamic>?;
    return WalkingCourseModel(
      course: courseJson != null ? WalkingCourseRouteModel.fromJson(courseJson) : null,
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .map((e) => NearbyRecommendationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
