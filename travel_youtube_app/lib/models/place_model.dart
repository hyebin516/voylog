class PlaceModel {
  final String placeId;
  final String name;
  final int? timestampSec;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String source;
  final double confidence;
  final String? category;
  final Map<String, dynamic>? businessHours;
  final bool businessHoursIsEstimated;
  final List<String> tags;
  final String? mentionNote;

  const PlaceModel({
    required this.placeId,
    required this.name,
    required this.timestampSec,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.source,
    required this.confidence,
    this.category,
    this.businessHours,
    this.businessHoursIsEstimated = false,
    this.tags = const [],
    this.mentionNote,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      timestampSec: json['timestampSec'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      source: json['source'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      category: json['category'] as String?,
      businessHours: (json['businessHours'] as Map?)?.cast<String, dynamic>(),
      businessHoursIsEstimated: json['businessHoursIsEstimated'] as bool? ?? false,
      tags: (json['tags'] as List?)
              ?.map((tag) => (tag as Map)['code'] as String)
              .toList() ??
          const [],
      mentionNote: json['mentionNote'] as String?,
    );
  }
}
