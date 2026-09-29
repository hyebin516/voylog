class RoutePointModel {
  final int order;
  final String type; // 'hotel' | 'place'
  final String? hotelId;
  final String? placeId;
  final String name;
  final double? latitude;
  final double? longitude;
  // Distance/duration of the leg arriving at this point from the previous
  // point in the route -- null for the first point (order 0).
  final int? legDistanceM;
  final int? legDurationSec;

  /// How that leg is travelled on a route that mixes modes -- 'walk' or
  /// 'transit' (a bookmark-folder route, FR-11; 'car' in courses saved
  /// before it switched to buses). Null when the whole route uses one
  /// transport mode.
  final String? legTransportMode;

  /// For a bus leg: which bus, between which stops -- "600번 · 온양온천역
  /// 신한은행 → 신정호관광지 건너".
  final String? legGuidance;

  /// The road this leg actually follows, as [latitude, longitude] pairs.
  /// Null on the first point, on legs where Kakao routing was unavailable,
  /// and on routes saved before the geometry was captured -- the map draws a
  /// straight line between the stops in those cases.
  final List<List<double>>? legPath;

  const RoutePointModel({
    required this.order,
    required this.type,
    required this.hotelId,
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.legDistanceM,
    this.legDurationSec,
    this.legPath,
    this.legTransportMode,
    this.legGuidance,
  });

  /// True when the leg arriving here is ridden by bus rather than walked.
  bool get isTransitLeg => legTransportMode == 'transit';

  /// True for a driven leg (bookmark-folder courses saved before buses).
  bool get isDrivenLeg => legTransportMode == 'car';

  /// Sentinel hotelId the AI worker uses for an FR-17 walking course that
  /// the user generated without picking a real hotel -- the round trip is
  /// anchored on the region's center point instead, named after the region
  /// (e.g. "부산"). Never a real `hotels.hotel_id`.
  static const String virtualRegionAnchorId = 'region-center';

  bool get isHotel => type == 'hotel';

  /// True for the synthetic region-center anchor above: a routing artifact,
  /// not a place the user can visit, so screens hide it rather than showing
  /// it as a stop.
  bool get isVirtualRegionAnchor => hotelId == virtualRegionAnchorId;

  /// Sentinel hotelId for a start point the user picked for an FR-17 walking
  /// course. Unlike the region-center anchor this is a real spot the walk
  /// begins and ends at, so screens show it (as "출발") instead of hiding it.
  static const String userStartPointId = 'start-point';

  bool get isUserStartPoint => hotelId == userStartPointId;

  /// Stable id for map marker/selection matching -- a real place/hotel id
  /// when there is one, else the point's name (e.g. the FR-17 region-center
  /// virtual anchor, which has neither).
  String get markerId => placeId ?? hotelId ?? name;

  factory RoutePointModel.fromJson(Map<String, dynamic> json) {
    return RoutePointModel(
      order: json['order'] as int,
      type: json['type'] as String,
      hotelId: json['hotelId'] as String?,
      placeId: json['placeId'] as String?,
      name: json['name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      legDistanceM: json['legDistanceM'] as int?,
      legDurationSec: json['legDurationSec'] as int?,
      legPath: (json['legPath'] as List<dynamic>?)
          ?.map((point) => (point as List<dynamic>).map((n) => (n as num).toDouble()).toList())
          .toList(),
      legTransportMode: json['legTransportMode'] as String?,
      legGuidance: json['legGuidance'] as String?,
    );
  }

  /// The shape the backend stores a route point in. Keeps the leg data,
  /// which saved courses used to drop -- so a saved course lost its
  /// per-stop travel times.
  Map<String, dynamic> toJson() => {
        'order': order,
        'type': type,
        'hotelId': hotelId,
        'placeId': placeId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'legDistanceM': legDistanceM,
        'legDurationSec': legDurationSec,
        if (legTransportMode != null) 'legTransportMode': legTransportMode,
        if (legGuidance != null) 'legGuidance': legGuidance,
        if (legPath != null) 'legPath': legPath,
      };
}

class ItineraryModel {
  final String itineraryId;
  final String tripId;
  final int dayNumber;
  final String startHotelId;
  final String endHotelId;
  final String routeType; // 'roundTrip' | 'hotelToHotel'
  final String optimizationPriority;
  final String transportMode; // 'car' | 'walk'
  final int? totalDistanceM;
  final int? totalDurationSec;
  final List<RoutePointModel> routeData;

  const ItineraryModel({
    required this.itineraryId,
    required this.tripId,
    required this.dayNumber,
    required this.startHotelId,
    required this.endHotelId,
    required this.routeType,
    required this.optimizationPriority,
    required this.transportMode,
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.routeData,
  });

  bool get isRoundTrip => routeType == 'roundTrip';
  bool get isWalk => transportMode == 'walk';

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    return ItineraryModel(
      itineraryId: json['itineraryId'] as String,
      tripId: json['tripId'] as String,
      dayNumber: json['dayNumber'] as int,
      startHotelId: json['startHotelId'] as String,
      endHotelId: json['endHotelId'] as String,
      routeType: json['routeType'] as String,
      optimizationPriority: json['optimizationPriority'] as String,
      transportMode: json['transportMode'] as String? ?? 'car',
      totalDistanceM: json['totalDistanceM'] as int?,
      totalDurationSec: json['totalDurationSec'] as int?,
      routeData: (json['routeData'] as List<dynamic>? ?? [])
          .map((e) => RoutePointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
