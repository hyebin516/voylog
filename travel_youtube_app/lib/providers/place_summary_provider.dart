import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/place_summary_model.dart';
import '../repositories/place_summary_repository.dart';
import '../utils/view_state.dart';

class PlaceSummaryProvider extends ChangeNotifier {
  final PlaceSummaryRepository _repository;

  PlaceSummaryProvider({PlaceSummaryRepository? repository}) : _repository = repository ?? PlaceSummaryRepository();

  ViewState _state = ViewState.idle;
  PlaceSummaryModel? _summary;
  String? _errorMessage;

  ViewState get state => _state;
  PlaceSummaryModel? get summary => _summary;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  Future<void> load(String placeId) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _repository.getSummary(placeId);
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }
}
