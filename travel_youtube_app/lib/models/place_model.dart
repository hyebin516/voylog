class PlaceModel {
  final String placeId;
  final String name;
  final int? timestampSec;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String source;
  final double confidence;

  const PlaceModel({
    required this.placeId,
    required this.name,
    required this.timestampSec,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.source,
    required this.confidence,
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
    );
  }
}
