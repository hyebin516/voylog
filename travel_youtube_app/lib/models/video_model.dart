import 'place_model.dart';

class VideoModel {
  final String videoId;
  final String? title;
  final bool isCached;
  final List<PlaceModel> places;

  const VideoModel({
    required this.videoId,
    required this.title,
    required this.isCached,
    required this.places,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      videoId: json['videoId'] as String,
      title: json['title'] as String?,
      isCached: json['isCached'] as bool? ?? false,
      places: (json['places'] as List<dynamic>? ?? [])
          .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
