class SharedRouteModel {
  final String sharedRouteId;
  final String title;
  final String? authorNickname;
  final String transportMode;
  final int placeCount;
  final int? totalDistanceM;
  final int? totalDurationSec;
  final int likeCount;
  final bool likedByMe;
  final bool isOwner;
  final int? matchPercent;
  final DateTime createdAt;

  const SharedRouteModel({
    required this.sharedRouteId,
    required this.title,
    required this.authorNickname,
    required this.transportMode,
    required this.placeCount,
    required this.totalDistanceM,
    required this.totalDurationSec,
    required this.likeCount,
    required this.likedByMe,
    required this.isOwner,
    required this.matchPercent,
    required this.createdAt,
  });

  SharedRouteModel copyWith({int? likeCount, bool? likedByMe, String? title}) {
    return SharedRouteModel(
      sharedRouteId: sharedRouteId,
      title: title ?? this.title,
      authorNickname: authorNickname,
      transportMode: transportMode,
      placeCount: placeCount,
      totalDistanceM: totalDistanceM,
      totalDurationSec: totalDurationSec,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      isOwner: isOwner,
      matchPercent: matchPercent,
      createdAt: createdAt,
    );
  }

  factory SharedRouteModel.fromJson(Map<String, dynamic> json) {
    return SharedRouteModel(
      sharedRouteId: json['sharedRouteId'] as String,
      title: json['title'] as String,
      authorNickname: json['authorNickname'] as String?,
      transportMode: json['transportMode'] as String,
      placeCount: json['placeCount'] as int,
      totalDistanceM: json['totalDistanceM'] as int?,
      totalDurationSec: json['totalDurationSec'] as int?,
      likeCount: json['likeCount'] as int,
      likedByMe: json['likedByMe'] as bool,
      isOwner: json['isOwner'] as bool? ?? false,
      matchPercent: json['matchPercent'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
