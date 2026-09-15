import 'place_model.dart';

class VideoModel {
  /// Our internal DB row id (`videos.video_id`, a UUID) -- not a YouTube
  /// video id, so never pass this to a YouTube player.
  final String videoId;

  /// The actual YouTube video id (e.g. `7_wkG4d7dhY`), for embedding the
  /// player. Nullable defensively (e.g. malformed `youtube_url` rows from
  /// before this field existed), though the backend should always send it.
  final String? youtubeVideoId;
  final String? title;
  final bool isCached;

  /// True while the backend is still reading place names off the video's
  /// screen in the background. More places may appear shortly, so the
  /// screen keeps refreshing while this is set.
  final bool enrichmentPending;
  final List<PlaceModel> places;

  const VideoModel({
    required this.videoId,
    required this.youtubeVideoId,
    required this.title,
    required this.isCached,
    this.enrichmentPending = false,
    required this.places,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      videoId: json['videoId'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String?,
      title: json['title'] as String?,
      isCached: json['isCached'] as bool? ?? false,
      enrichmentPending: json['enrichmentPending'] as bool? ?? false,
      places: (json['places'] as List<dynamic>? ?? [])
          .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
