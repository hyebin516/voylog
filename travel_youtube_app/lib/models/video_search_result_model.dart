class VideoSearchResultModel {
  final String videoId;
  final String youtubeUrl;
  final String title;
  final String? thumbnailUrl;
  final String? channelName;
  final String? publishedAt;

  const VideoSearchResultModel({
    required this.videoId,
    required this.youtubeUrl,
    required this.title,
    required this.thumbnailUrl,
    required this.channelName,
    required this.publishedAt,
  });

  factory VideoSearchResultModel.fromJson(Map<String, dynamic> json) {
    return VideoSearchResultModel(
      videoId: json['videoId'] as String,
      youtubeUrl: json['youtubeUrl'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      channelName: json['channelName'] as String?,
      publishedAt: json['publishedAt'] as String?,
    );
  }
}
