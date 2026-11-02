import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/place_model.dart';
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
  int analyzeCalls = 0;
  /// Successive responses for the enrichment-polling tests; falls back to
  /// [videoToReturn] once exhausted.
  List<VideoModel> analyzeQueue = [];

  List<VideoSearchResultModel> searchResultsToReturn = [];
  ApiException? searchError;
  String? lastHashtag;

  List<String>? lastRegions;
  List<String>? lastThemes;
  String? lastDuration;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    lastUrl = youtubeUrl;
    analyzeCalls++;
    if (error != null) throw error!;
    if (analyzeQueue.isNotEmpty) return analyzeQueue.removeAt(0);
    return videoToReturn!;
  }

  @override
  Future<List<VideoSearchResultModel>> searchByHashtag(String hashtag) async {
    lastHashtag = hashtag;
    if (searchError != null) throw searchError!;
    return searchResultsToReturn;
  }

  @override
  Future<List<VideoSearchResultModel>> getRecommendations({
    required List<String> regions,
    required List<String> themes,
    required String duration,
  }) async {
    lastRegions = regions;
    lastThemes = themes;
    lastDuration = duration;
    if (searchError != null) throw searchError!;
    return searchResultsToReturn;
  }
}

void main() {
  group('enrichment polling', _enrichmentTests);
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
      repository.videoToReturn = const VideoModel(videoId: 'v1', youtubeVideoId: 'v1', title: 'Trip', isCached: false, places: []);

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
    repository.videoToReturn = const VideoModel(videoId: 'v1', youtubeVideoId: 'v1', title: 'Trip', isCached: false, places: []);
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
      repository.videoToReturn = const VideoModel(videoId: 'v1', youtubeVideoId: 'v1', title: 'Trip', isCached: false, places: []);
      await provider.analyze('https://youtu.be/dQw4w9WgXcQ');

      repository.searchResultsToReturn = [_searchResult];
      await provider.searchByHashtag('부산여행');

      expect(provider.state, ViewState.success);
      expect(provider.currentVideo?.videoId, 'v1');
      expect(provider.searchState, ViewState.success);
    });
  });

  group('searchByRecommendation', () {
    test('transitions to success and stores the results', () async {
      repository.searchResultsToReturn = [_searchResult];

      await provider.searchByRecommendation(regions: ['제주'], themes: ['자연'], duration: '1박 2일');

      expect(repository.lastRegions, ['제주']);
      expect(repository.lastThemes, ['자연']);
      expect(repository.lastDuration, '1박 2일');
      expect(provider.searchState, ViewState.success);
      expect(provider.searchResults, [_searchResult]);
    });

    test('transitions to error with a friendly message on failure', () async {
      repository.searchError = const ApiException(code: 'YOUTUBE_SEARCH_FAILED', message: 'boom');

      await provider.searchByRecommendation(regions: ['제주'], themes: ['자연'], duration: '1박 2일');

      expect(provider.searchState, ViewState.error);
      expect(provider.searchErrorMessage, isNotNull);
      expect(provider.searchResults, isEmpty);
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

VideoModel _video({required int placeCount, required bool enrichmentPending}) {
  return VideoModel(
    videoId: 'v1',
    youtubeVideoId: 'abc',
    title: 't',
    isCached: false,
    enrichmentPending: enrichmentPending,
    places: List.generate(
      placeCount,
      (i) => PlaceModel(
        placeId: 'p$i',
        name: '장소$i',
        timestampSec: null,
        latitude: null,
        longitude: null,
        address: null,
        source: 'transcript',
        confidence: 0.8,
      ),
    ),
  );
}

void _enrichmentTests() {
  test('does not poll when the backend reports no pending enrichment', () {
    fakeAsync((async) {
      final repository = FakeVideoRepository()
        ..videoToReturn = _video(placeCount: 6, enrichmentPending: false);
      final provider = VideoProvider(repository: repository);

      provider.analyze('https://youtu.be/abc');
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));

      expect(repository.analyzeCalls, 1);
    });
  });

  test('polls while enrichment is pending and adopts the extra places', () {
    fakeAsync((async) {
      final repository = FakeVideoRepository()
        ..analyzeQueue = [
          _video(placeCount: 2, enrichmentPending: true),
          _video(placeCount: 2, enrichmentPending: true),
          _video(placeCount: 7, enrichmentPending: false),
        ]
        ..videoToReturn = _video(placeCount: 7, enrichmentPending: false);
      final provider = VideoProvider(repository: repository);

      provider.analyze('https://youtu.be/abc');
      async.flushMicrotasks();
      expect(provider.currentVideo!.places, hasLength(2));

      // 폴링 간격은 5초다(보강이 20~40초면 끝나므로).
      async.elapse(const Duration(seconds: 6));
      async.flushMicrotasks();
      expect(provider.currentVideo!.places, hasLength(2)); // nothing new yet

      async.elapse(const Duration(seconds: 6));
      async.flushMicrotasks();
      expect(provider.currentVideo!.places, hasLength(7));

      // Enrichment reported done, so polling stops.
      final callsAfterDone = repository.analyzeCalls;
      async.elapse(const Duration(minutes: 5));
      expect(repository.analyzeCalls, callsAfterDone);
    });
  });

  test('stops polling when the analysis is reset', () {
    fakeAsync((async) {
      final repository = FakeVideoRepository()
        ..videoToReturn = _video(placeCount: 2, enrichmentPending: true);
      final provider = VideoProvider(repository: repository);

      provider.analyze('https://youtu.be/abc');
      async.flushMicrotasks();
      provider.reset();

      final callsAtReset = repository.analyzeCalls;
      async.elapse(const Duration(minutes: 5));

      expect(repository.analyzeCalls, callsAtReset);
    });
  });
}
