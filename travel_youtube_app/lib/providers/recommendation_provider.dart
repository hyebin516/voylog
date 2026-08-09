import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/nearby_recommendation_model.dart';
import '../repositories/behavior_repository.dart';
import '../repositories/recommendation_repository.dart';
import '../utils/view_state.dart';

const String _nearbyScreenName = 'nearby';

class RecommendationProvider extends ChangeNotifier {
  final RecommendationRepository _repository;
  final BehaviorRepository _behaviorRepository;

  RecommendationProvider({RecommendationRepository? repository, BehaviorRepository? behaviorRepository})
      : _repository = repository ?? RecommendationRepository(),
        _behaviorRepository = behaviorRepository ?? BehaviorRepository();

  ViewState _state = ViewState.idle;
  List<NearbyRecommendationModel> _recommendations = [];
  String? _errorMessage;

  ViewState get state => _state;
  List<NearbyRecommendationModel> get recommendations => _recommendations;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  Future<void> loadNearby({required double latitude, required double longitude}) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _recommendations = await _repository.getNearby(latitude: latitude, longitude: longitude, localTime: DateTime.now());
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  // Behavior tracking is best-effort: it feeds phase-5 personalized learning
  // on the backend, but a failed recording call must never break the
  // recommendation browsing experience itself.
  Future<void> _recordBehavior(String placeId, String action, {int? distanceMeters}) async {
    try {
      await _behaviorRepository.record(
        placeId: placeId,
        action: action,
        screen: _nearbyScreenName,
        distanceMeters: distanceMeters,
      );
    } on ApiException {
      // swallow: behavior logging failures are not user-facing
    }
  }

  Future<void> recordViewDetail(NearbyRecommendationModel place) {
    return _recordBehavior(place.placeId, 'view_detail', distanceMeters: place.distanceMeters);
  }

  Future<void> recordBookmark(NearbyRecommendationModel place) {
    return _recordBehavior(place.placeId, 'bookmark', distanceMeters: place.distanceMeters);
  }

  // Optimistically drops the place from the current list -- the backend's
  // hidden-place filter (recommendation.repository.js) keeps it out of
  // future requests once this recording call lands.
  Future<void> markNotInterested(NearbyRecommendationModel place) async {
    _recommendations = _recommendations.where((r) => r.placeId != place.placeId).toList();
    notifyListeners();
    await _recordBehavior(place.placeId, 'not_interested', distanceMeters: place.distanceMeters);
  }
}
