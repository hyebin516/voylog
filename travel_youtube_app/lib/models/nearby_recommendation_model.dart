class NearbyRecommendationModel {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final String? category;
  final bool? isOpen;
  final bool isOpenEstimated;
  final double score;
  final String reason;

  const NearbyRecommendationModel({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.category,
    required this.isOpen,
    required this.isOpenEstimated,
    required this.score,
    required this.reason,
  });

  factory NearbyRecommendationModel.fromJson(Map<String, dynamic> json) {
    return NearbyRecommendationModel(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceMeters: json['distanceMeters'] as int,
      category: json['category'] as String?,
      isOpen: json['isOpen'] as bool?,
      isOpenEstimated: json['isOpenEstimated'] as bool,
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String,
    );
  }
}
