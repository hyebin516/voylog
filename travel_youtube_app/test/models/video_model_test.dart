import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/video_model.dart';

void main() {
  group('VideoModel.fromJson', () {
    test('parses a video with its places', () {
      final video = VideoModel.fromJson({
        'videoId': 'v1',
        'title': 'My Trip',
        'isCached': true,
        'places': [
          {
            'placeId': 'p1',
            'name': 'Place 1',
            'timestampSec': 10,
            'latitude': 35.0,
            'longitude': 129.0,
            'address': 'addr',
            'source': 'transcript',
            'confidence': 0.8,
          },
        ],
      });

      expect(video.videoId, 'v1');
      expect(video.title, 'My Trip');
      expect(video.isCached, isTrue);
      expect(video.places, hasLength(1));
      expect(video.places.first.name, 'Place 1');
    });

    test('defaults isCached to false when the field is missing', () {
      final video = VideoModel.fromJson({'videoId': 'v1', 'title': null, 'places': []});
      expect(video.isCached, isFalse);
    });

    test('defaults places to an empty list when the field is missing (never null)', () {
      final video = VideoModel.fromJson({'videoId': 'v1', 'title': null});
      expect(video.places, isEmpty);
    });

    test('title may be null (not yet analyzed with YouTube API metadata)', () {
      final video = VideoModel.fromJson({'videoId': 'v1', 'title': null, 'places': []});
      expect(video.title, isNull);
    });
  });
}
