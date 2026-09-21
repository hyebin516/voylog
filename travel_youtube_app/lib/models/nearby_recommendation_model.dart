class NearbyRecommendationModel {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final String? category;
  // Carried from the stored place so tapping a card opens the place detail
  // screen complete -- address, hours and tags -- with no second request.
  final String? address;
  final Map<String, dynamic>? businessHours;
  final bool businessHoursIsEstimated;
  final List<String> tags;
  final bool? isOpen;
  final bool isOpenEstimated;
  final double score;
  final List<String> matchedTags;
  final String reason;

  const NearbyRecommendationModel({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.category,
    this.address,
    this.businessHours,
    this.businessHoursIsEstimated = false,
    this.tags = const [],
    required this.isOpen,
    required this.isOpenEstimated,
    required this.score,
    required this.matchedTags,
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
      address: json['address'] as String?,
      businessHours: (json['businessHours'] as Map?)?.cast<String, dynamic>(),
      businessHoursIsEstimated: json['businessHoursIsEstimated'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      isOpen: json['isOpen'] as bool?,
      isOpenEstimated: json['isOpenEstimated'] as bool,
      score: (json['score'] as num).toDouble(),
      matchedTags: (json['matchedTags'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      reason: json['reason'] as String,
    );
  }
}
