import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/nearby_recommendation_model.dart';
import '../repositories/recommendation_repository.dart';
import '../utils/view_state.dart';

class RecommendationProvider extends ChangeNotifier {
  final RecommendationRepository _repository;

  RecommendationProvider({RecommendationRepository? repository}) : _repository = repository ?? RecommendationRepository();

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
}
