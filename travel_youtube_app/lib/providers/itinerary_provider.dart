import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/itinerary_model.dart';
import '../repositories/itinerary_repository.dart';
import '../utils/view_state.dart';

const int kMinRoutePlaces = 2;
const int kMaxRoutePlaces = 10;

class ItineraryProvider extends ChangeNotifier {
  final ItineraryRepository _repository;

  ItineraryProvider({ItineraryRepository? repository}) : _repository = repository ?? ItineraryRepository();

  ViewState _state = ViewState.idle;
  final Set<String> _selectedPlaceIds = {};
  ItineraryModel? _result;
  String? _errorMessage;
  String _transportMode = 'car';

  ViewState get state => _state;
  Set<String> get selectedPlaceIds => _selectedPlaceIds;
  ItineraryModel? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;
  String get transportMode => _transportMode;

  void selectTransportMode(String mode) {
    _transportMode = mode;
    notifyListeners();
  }

  bool get canOptimize =>
      _selectedPlaceIds.length >= kMinRoutePlaces && _selectedPlaceIds.length <= kMaxRoutePlaces;

  bool isSelected(String placeId) => _selectedPlaceIds.contains(placeId);

  void togglePlaceSelection(String placeId) {
    if (_selectedPlaceIds.contains(placeId)) {
      _selectedPlaceIds.remove(placeId);
    } else if (_selectedPlaceIds.length < kMaxRoutePlaces) {
      _selectedPlaceIds.add(placeId);
    }
    notifyListeners();
  }

  Future<void> optimize({
    required String tripId,
    required int dayNumber,
    required String startHotelId,
    required String endHotelId,
  }) async {
    if (!canOptimize) return;

    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _result = await _repository.createItinerary(
        tripId: tripId,
        dayNumber: dayNumber,
        startHotelId: startHotelId,
        endHotelId: endHotelId,
        placeIds: _selectedPlaceIds.toList(),
        transportMode: _transportMode,
      );
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  void reset() {
    _selectedPlaceIds.clear();
    _result = null;
    _state = ViewState.idle;
    _transportMode = 'car';
    notifyListeners();
  }
}
