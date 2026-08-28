import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/similar_taste_recommendation_model.dart';
import '../repositories/similar_taste_repository.dart';
import '../utils/view_state.dart';

class SimilarTasteProvider extends ChangeNotifier {
  final SimilarTasteRepository _repository;

  SimilarTasteProvider({SimilarTasteRepository? repository}) : _repository = repository ?? SimilarTasteRepository();

  ViewState _state = ViewState.idle;
  SimilarTasteResultModel? _result;
  String? _errorMessage;

  ViewState get state => _state;
  SimilarTasteResultModel? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  Future<void> load() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _result = await _repository.getRecommendations();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }
}
