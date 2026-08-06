import 'itinerary_model.dart';

/// Summary shape returned by `GET /trips` (list).
class TripModel {
  final String tripId;
  final String name;
  final int dayCount;
  final DateTime createdAt;

  const TripModel({
    required this.tripId,
    required this.name,
    required this.dayCount,
    required this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      tripId: json['tripId'] as String,
      name: json['name'] as String,
      dayCount: json['dayCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Full shape returned by `GET /trips/:id` (detail), including each day's
/// itinerary ordered by dayNumber.
class TripDetailModel {
  final String tripId;
  final String name;
  final DateTime createdAt;
  final List<ItineraryModel> days;

  const TripDetailModel({
    required this.tripId,
    required this.name,
    required this.createdAt,
    required this.days,
  });

  factory TripDetailModel.fromJson(Map<String, dynamic> json) {
    return TripDetailModel(
      tripId: json['tripId'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      days: (json['days'] as List<dynamic>? ?? [])
          .map((e) => ItineraryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
