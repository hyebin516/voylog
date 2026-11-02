import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/video_model.dart';
import '../models/video_search_result_model.dart';
import '../repositories/video_repository.dart';
import '../utils/view_state.dart';

// How the screen keeps up with the backend's background on-screen-text
// pass. 실측으로 보강은 20~40초면 끝나는데 20초 간격으로 묻다 보니 끝난
// 뒤에도 평균 10초를 더 기다렸다. 폴링은 캐시 조회라 값이 싸므로 5초로
// 좁히고, 대신 횟수를 늘려 5분이라는 전체 한도는 그대로 둔다 -- 작업이
// 죽었을 때 영원히 도는 것을 막는 장치다.
const Duration _enrichmentPollInterval = Duration(seconds: 5);
const int _enrichmentPollLimit = 60;

class VideoProvider extends ChangeNotifier {
  final VideoRepository _repository;

  VideoProvider({VideoRepository? repository})
    : _repository = repository ?? VideoRepository();

  ViewState _state = ViewState.idle;
  VideoModel? _currentVideo;
  String? _errorMessage;

  ViewState get state => _state;
  VideoModel? get currentVideo => _currentVideo;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  ViewState _searchState = ViewState.idle;
  List<VideoSearchResultModel> _searchResults = [];
  String? _searchErrorMessage;

  ViewState get searchState => _searchState;
  List<VideoSearchResultModel> get searchResults => _searchResults;
  String? get searchErrorMessage => _searchErrorMessage;
  bool get isSearching => _searchState == ViewState.loading;

  Timer? _enrichmentTimer;

  Future<void> analyze(String youtubeUrl) async {
    _state = ViewState.loading;
    _errorMessage = null;
    _enrichmentTimer?.cancel();
    notifyListeners();

    try {
      _currentVideo = await _repository.analyze(youtubeUrl);
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();

    if (_currentVideo?.enrichmentPending ?? false) {
      _watchForEnrichedPlaces(youtubeUrl);
    }
  }

  /// Re-fetches the analysis while the backend is still reading place names
  /// off the video's screen, so the extra places appear without the user
  /// having to do anything.
  ///
  /// The backend answers from cache until the job finishes, so these polls
  /// are cheap; it gives up after [_enrichmentPollLimit] rather than
  /// polling forever if the job dies.
  void _watchForEnrichedPlaces(String youtubeUrl) {
    var polls = 0;

    _enrichmentTimer = Timer.periodic(_enrichmentPollInterval, (timer) async {
      if (polls++ >= _enrichmentPollLimit) {
        timer.cancel();
        return;
      }

      final VideoModel refreshed;
      try {
        refreshed = await _repository.analyze(youtubeUrl);
      } on ApiException {
        // Keep what's on screen; a failed poll isn't worth surfacing.
        return;
      }

      final isSameVideo = refreshed.videoId == _currentVideo?.videoId;
      if (!isSameVideo) {
        timer.cancel();
        return;
      }

      if (!refreshed.enrichmentPending) timer.cancel();

      // 받은 결과를 항상 채택한다. 전에는 "장소가 늘었을 때만" 바꿨는데,
      // 그러면 두 가지가 깨진다. 첫째, 개수가 그대로면 옛 데이터의
      // enrichmentPending=true가 남아 "더 찾고 있어요" 배너가 끝나도
      // 사라지지 않는다. 둘째, 보강이 이름을 고치거나 좌표를 채워 넣어도
      // (경포 해수역장 -> 경포 해수욕장) 개수가 같으면 버려진다.
      _currentVideo = refreshed;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _enrichmentTimer?.cancel();
    super.dispose();
  }

  Future<void> searchByHashtag(String hashtag) async {
    _searchState = ViewState.loading;
    _searchErrorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _repository.searchByHashtag(hashtag);
      _searchState = ViewState.success;
    } on ApiException catch (e) {
      _searchState = ViewState.error;
      _searchErrorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  /// Backs the region/theme/duration recommendation wizard. Shares the same
  /// searchResults/searchState as [searchByHashtag] — both are "browse for a
  /// video to analyze" flows and are never shown on screen at the same time.
  Future<void> searchByRecommendation({
    required List<String> regions,
    required List<String> themes,
    required String duration,
  }) async {
    _searchState = ViewState.loading;
    _searchErrorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _repository.getRecommendations(
        regions: regions,
        themes: themes,
        duration: duration,
      );
      _searchState = ViewState.success;
    } on ApiException catch (e) {
      _searchState = ViewState.error;
      _searchErrorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  void clearSearch() {
    _searchState = ViewState.idle;
    _searchResults = [];
    _searchErrorMessage = null;
    notifyListeners();
  }

  /// Clears a failed analysis without discarding the video already on the
  /// 분석 tab: cancelling one failure should not erase the last result the
  /// user still has open there.
  void dismissAnalysisError() {
    if (_state != ViewState.error) return;
    _state = _currentVideo != null ? ViewState.success : ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _enrichmentTimer?.cancel();
    _state = ViewState.idle;
    _currentVideo = null;
    _errorMessage = null;
    notifyListeners();
  }
}
