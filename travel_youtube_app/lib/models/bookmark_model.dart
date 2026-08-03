class BookmarkModel {
  final String bookmarkId;
  final String placeId;
  final String? videoId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? timestampSec;
  final String source;
  final double confidence;
  final DateTime bookmarkedAt;

  const BookmarkModel({
    required this.bookmarkId,
    required this.placeId,
    required this.videoId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.timestampSec,
    required this.source,
    required this.confidence,
    required this.bookmarkedAt,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      bookmarkId: json['bookmarkId'] as String,
      placeId: json['placeId'] as String,
      videoId: json['videoId'] as String?,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timestampSec: json['timestampSec'] as int?,
      source: json['source'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      bookmarkedAt: DateTime.parse(json['bookmarkedAt'] as String),
    );
  }
}
