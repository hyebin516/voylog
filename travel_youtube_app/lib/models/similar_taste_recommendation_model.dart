class SimilarTasteRecommendationModel {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String? category;
  final double score;
  final int contributorCount;
  final String reason;

  const SimilarTasteRecommendationModel({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.score,
    required this.contributorCount,
    required this.reason,
  });

  factory SimilarTasteRecommendationModel.fromJson(Map<String, dynamic> json) {
    return SimilarTasteRecommendationModel(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String?,
      score: (json['score'] as num).toDouble(),
      contributorCount: json['contributorCount'] as int,
      reason: json['reason'] as String,
    );
  }
}

/// Wraps the recommendation list with whether the requester has a taste
/// preference set at all -- `hasPreference: false` means there's nothing to
/// compare against yet (never took the taste survey, no learned behavior),
/// which is a distinct empty state from "no similar users found".
class SimilarTasteResultModel {
  final bool hasPreference;
  final List<SimilarTasteRecommendationModel> recommendations;

  const SimilarTasteResultModel({required this.hasPreference, required this.recommendations});

  factory SimilarTasteResultModel.fromJson(Map<String, dynamic> json) {
    return SimilarTasteResultModel(
      hasPreference: json['hasPreference'] as bool,
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .map((e) => SimilarTasteRecommendationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
