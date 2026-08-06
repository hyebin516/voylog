class RoutePointModel {
  final int order;
  final String type; // 'hotel' | 'place'
  final String? hotelId;
  final String? placeId;
  final String name;
  final double? latitude;
  final double? longitude;

  const RoutePointModel({
    required this.order,
    required this.type,
    required this.hotelId,
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  bool get isHotel => type == 'hotel';

  factory RoutePointModel.fromJson(Map<String, dynamic> json) {
    return RoutePointModel(
      order: json['order'] as int,
      type: json['type'] as String,
      hotelId: json['hotelId'] as String?,
      placeId: json['placeId'] as String?,
      name: json['name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class ItineraryModel {
  final String itineraryId;
  final String tripId;
  final int dayNumber;
  final String startHotelId;
  final String endHotelId;
  final String routeType; // 'roundTrip' | 'hotelToHotel'
  final String optimizationPriority;
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
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.routeData,
  });

  bool get isRoundTrip => routeType == 'roundTrip';

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    return ItineraryModel(
      itineraryId: json['itineraryId'] as String,
      tripId: json['tripId'] as String,
      dayNumber: json['dayNumber'] as int,
      startHotelId: json['startHotelId'] as String,
      endHotelId: json['endHotelId'] as String,
      routeType: json['routeType'] as String,
      optimizationPriority: json['optimizationPriority'] as String,
      totalDistanceM: json['totalDistanceM'] as int?,
      totalDurationSec: json['totalDurationSec'] as int?,
      routeData: (json['routeData'] as List<dynamic>? ?? [])
          .map((e) => RoutePointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
