import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/bookmark_model.dart';
import '../models/itinerary_model.dart';
import '../repositories/itinerary_repository.dart';
import '../utils/view_state.dart';

const int kMinRoutePlaces = 2;
const int kMaxRoutePlaces = 10;

class ItineraryProvider extends ChangeNotifier {
  final ItineraryRepository _repository;

  ItineraryProvider({ItineraryRepository? repository})
    : _repository = repository ?? ItineraryRepository();

  ViewState _state = ViewState.idle;

  /// Populated in one shot from the folder picked in the "N일차 북마크 선택"
  /// step -- individual places can still be dropped afterwards (design's
  /// "다음 단계에서 장소를 더 줄일 수 있어요"), but there's no per-place
  /// toggle-from-a-flat-list step anymore.
  final List<BookmarkModel> _selectedPlaces = [];
  ItineraryModel? _result;
  String? _errorMessage;
  String _transportMode = 'car';
  String? _sourceFolderId;
  String? _sourceFolderName;

  ViewState get state => _state;
  List<BookmarkModel> get selectedPlaces => _selectedPlaces;
  Set<String> get selectedPlaceIds =>
      _selectedPlaces.map((p) => p.placeId).toSet();
  ItineraryModel? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;
  String get transportMode => _transportMode;
  String? get sourceFolderId => _sourceFolderId;
  String? get sourceFolderName => _sourceFolderName;

  void selectTransportMode(String mode) {
    _transportMode = mode;
    notifyListeners();
  }

  bool get canOptimize =>
      _selectedPlaces.length >= kMinRoutePlaces &&
      _selectedPlaces.length <= kMaxRoutePlaces;

  /// Replaces the selection with a folder's places (capped at
  /// [kMaxRoutePlaces] -- the design notes the rest can be trimmed in the
  /// next step, not that every place in a large folder is used).
  void setSelectedPlacesFromFolder(
    String folderId,
    String folderName,
    List<BookmarkModel> places,
  ) {
    _sourceFolderId = folderId;
    _sourceFolderName = folderName;
    _selectedPlaces
      ..clear()
      ..addAll(places.take(kMaxRoutePlaces));
    notifyListeners();
  }

  void removePlace(String placeId) {
    _selectedPlaces.removeWhere((p) => p.placeId == placeId);
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
        placeIds: selectedPlaceIds.toList(),
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
    _selectedPlaces.clear();
    _sourceFolderId = null;
    _sourceFolderName = null;
    _result = null;
    _state = ViewState.idle;
    _transportMode = 'car';
    notifyListeners();
  }
}
