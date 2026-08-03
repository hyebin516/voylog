import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/video_search_result_model.dart';

void main() {
  group('VideoSearchResultModel.fromJson', () {
    test('parses a full search result', () {
      final result = VideoSearchResultModel.fromJson({
        'videoId': 'dQw4w9WgXcQ',
        'youtubeUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'title': '부산 여행 브이로그',
        'thumbnailUrl': 'http://thumb',
        'channelName': '채널',
        'publishedAt': '2026-01-01T00:00:00Z',
      });

      expect(result.videoId, 'dQw4w9WgXcQ');
      expect(result.youtubeUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(result.title, '부산 여행 브이로그');
      expect(result.thumbnailUrl, 'http://thumb');
      expect(result.channelName, '채널');
    });

    test('thumbnailUrl/channelName/publishedAt may be null', () {
      final result = VideoSearchResultModel.fromJson({
        'videoId': 'v1',
        'youtubeUrl': 'https://youtu.be/v1',
        'title': 'title',
        'thumbnailUrl': null,
        'channelName': null,
        'publishedAt': null,
      });

      expect(result.thumbnailUrl, isNull);
      expect(result.channelName, isNull);
      expect(result.publishedAt, isNull);
    });
  });
}
