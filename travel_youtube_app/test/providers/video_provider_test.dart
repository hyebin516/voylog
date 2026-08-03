import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

class FakeVideoRepository extends VideoRepository {
  VideoModel? videoToReturn;
  ApiException? error;
  String? lastUrl;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    lastUrl = youtubeUrl;
    if (error != null) throw error!;
    return videoToReturn!;
  }
}

void main() {
  late FakeVideoRepository repository;
  late VideoProvider provider;

  setUp(() {
    repository = FakeVideoRepository();
    provider = VideoProvider(repository: repository);
  });

  test('starts idle with no current video', () {
    expect(provider.state, ViewState.idle);
    expect(provider.currentVideo, isNull);
  });

  group('analyze', () {
    test('transitions to success and stores the analyzed video', () async {
      repository.videoToReturn = const VideoModel(videoId: 'v1', title: 'Trip', isCached: false, places: []);

      await provider.analyze('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

      expect(repository.lastUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(provider.state, ViewState.success);
      expect(provider.currentVideo?.videoId, 'v1');
    });

    test('transitions to error with a friendly message when the transcript is unavailable', () async {
      repository.error = const ApiException(code: 'TRANSCRIPT_NOT_FOUND', message: 'boom');

      await provider.analyze('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, '이 영상에는 자막이 없어 분석할 수 없습니다.');
      expect(provider.currentVideo, isNull);
    });
  });

  test('reset clears the current video, error, and returns to idle', () async {
    repository.videoToReturn = const VideoModel(videoId: 'v1', title: 'Trip', isCached: false, places: []);
    await provider.analyze('https://youtu.be/dQw4w9WgXcQ');

    provider.reset();

    expect(provider.state, ViewState.idle);
    expect(provider.currentVideo, isNull);
    expect(provider.errorMessage, isNull);
  });
}
