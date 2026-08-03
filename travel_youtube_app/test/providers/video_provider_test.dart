import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/models/video_search_result_model.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const VideoSearchResultModel _searchResult = VideoSearchResultModel(
  videoId: 'v1',
  youtubeUrl: 'https://youtu.be/v1',
  title: 'title',
  thumbnailUrl: null,
  channelName: null,
  publishedAt: null,
);

class FakeVideoRepository extends VideoRepository {
  VideoModel? videoToReturn;
  ApiException? error;
  String? lastUrl;

  List<VideoSearchResultModel> searchResultsToReturn = [];
  ApiException? searchError;
  String? lastHashtag;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    lastUrl = youtubeUrl;
    if (error != null) throw error!;
    return videoToReturn!;
  }

  @override
  Future<List<VideoSearchResultModel>> searchByHashtag(String hashtag) async {
    lastHashtag = hashtag;
    if (searchError != null) throw searchError!;
    return searchResultsToReturn;
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

  group('searchByHashtag', () {
    test('starts idle with no search results', () {
      expect(provider.searchState, ViewState.idle);
      expect(provider.searchResults, isEmpty);
    });

    test('transitions to success and stores the results', () async {
      repository.searchResultsToReturn = [_searchResult];

      await provider.searchByHashtag('부산여행');

      expect(repository.lastHashtag, '부산여행');
      expect(provider.searchState, ViewState.success);
      expect(provider.searchResults, [_searchResult]);
    });

    test('transitions to error with a friendly message on failure', () async {
      repository.searchError = const ApiException(code: 'AI_PROVIDER_ERROR', message: 'boom');

      await provider.searchByHashtag('부산여행');

      expect(provider.searchState, ViewState.error);
      expect(provider.searchErrorMessage, isNotNull);
      expect(provider.searchResults, isEmpty);
    });

    test('does not affect the separate analyze/currentVideo state', () async {
      repository.videoToReturn = const VideoModel(videoId: 'v1', title: 'Trip', isCached: false, places: []);
      await provider.analyze('https://youtu.be/dQw4w9WgXcQ');

      repository.searchResultsToReturn = [_searchResult];
      await provider.searchByHashtag('부산여행');

      expect(provider.state, ViewState.success);
      expect(provider.currentVideo?.videoId, 'v1');
      expect(provider.searchState, ViewState.success);
    });
  });

  test('clearSearch resets search results, error, and state to idle', () async {
    repository.searchResultsToReturn = [_searchResult];
    await provider.searchByHashtag('부산여행');

    provider.clearSearch();

    expect(provider.searchState, ViewState.idle);
    expect(provider.searchResults, isEmpty);
    expect(provider.searchErrorMessage, isNull);
  });
}
