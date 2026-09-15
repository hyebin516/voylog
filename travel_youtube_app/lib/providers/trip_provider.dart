import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../utils/view_state.dart';

class TripProvider extends ChangeNotifier {
  final TripRepository _repository;

  TripProvider({TripRepository? repository})
    : _repository = repository ?? TripRepository();

  ViewState _state = ViewState.idle;
  List<TripModel> _trips = [];
  TripDetailModel? _currentTrip;
  String? _errorMessage;

  /// Set while the user is inside the "add a day" flow (DayFolderSelectScreen
  /// -> RoutePlannerScreen) so RoutePlannerScreen knows which trip/day the
  /// itinerary it optimizes should be saved under.
  String? activeTripId;
  int? activeDayNumber;

  /// Set when the user starts the "add a day" flow from a specific bookmark
  /// folder (e.g. a "동선 생성" shortcut on that folder's screen) instead of
  /// from [TripDetailScreen]'s generic "날짜 추가" -- lets DayFolderSelectScreen
  /// pre-select that folder instead of making the user find it again.
  /// Consumed (read once, then cleared) by [takePendingFolderId].
  String? _pendingFolderId;

  void setPendingFolderId(String folderId) {
    _pendingFolderId = folderId;
  }

  String? takePendingFolderId() {
    final id = _pendingFolderId;
    _pendingFolderId = null;
    return id;
  }

  ViewState get state => _state;
  List<TripModel> get trips => _trips;
  TripDetailModel? get currentTrip => _currentTrip;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  /// The day number the "add a day" flow should create next.
  int get nextDayNumber => (_currentTrip?.days.length ?? 0) + 1;

  void startBuildingDay(String tripId, int dayNumber) {
    activeTripId = tripId;
    activeDayNumber = dayNumber;
  }

  void clearActiveDay() {
    activeTripId = null;
    activeDayNumber = null;
  }

  Future<void> loadTrips() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _trips = await _repository.listTrips();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<TripModel?> createTrip(
    String name, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final trip = await _repository.createTrip(
        name,
        startDate: startDate,
        endDate: endDate,
      );
      _trips = [trip, ..._trips];
      notifyListeners();
      return trip;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadTrip(String tripId) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentTrip = await _repository.getTrip(tripId);
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<bool> deleteTrip(String tripId) async {
    try {
      await _repository.deleteTrip(tripId);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    _trips = _trips.where((t) => t.tripId != tripId).toList();
    if (_currentTrip?.tripId == tripId) _currentTrip = null;
    notifyListeners();
    return true;
  }

  void clearCurrentTrip() {
    _currentTrip = null;
    notifyListeners();
  }

  Future<bool> updateTripDates(
    String tripId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await _repository.updateTripDates(
        tripId,
        startDate: startDate,
        endDate: endDate,
      );
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    await loadTrip(tripId);
    return true;
  }
}
