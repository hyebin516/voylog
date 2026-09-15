import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/hotel_model.dart';
import '../models/hotel_search_candidate.dart';
import '../repositories/hotel_repository.dart';
import '../utils/view_state.dart';

class HotelProvider extends ChangeNotifier {
  final HotelRepository _repository;

  HotelProvider({HotelRepository? repository})
    : _repository = repository ?? HotelRepository();

  ViewState _state = ViewState.idle;
  List<HotelModel> _hotels = [];
  String? _errorMessage;

  HotelModel? _selectedStartHotel;
  HotelModel? _selectedEndHotel;

  ViewState _searchState = ViewState.idle;
  List<HotelSearchCandidate> _searchResults = [];
  String? _searchErrorMessage;

  ViewState get state => _state;
  List<HotelModel> get hotels => _hotels;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  ViewState get searchState => _searchState;
  List<HotelSearchCandidate> get searchResults => _searchResults;
  String? get searchErrorMessage => _searchErrorMessage;
  bool get isSearching => _searchState == ViewState.loading;

  HotelModel? get selectedStartHotel => _selectedStartHotel;
  HotelModel? get selectedEndHotel => _selectedEndHotel;

  /// True when the user picked the same hotel for both endpoints.
  bool get isRoundTrip =>
      _selectedStartHotel != null &&
      _selectedEndHotel != null &&
      _selectedStartHotel!.hotelId == _selectedEndHotel!.hotelId;

  Future<void> loadHotels() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _hotels = await _repository.listHotels();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<HotelModel?> createHotel(HotelModel hotel) async {
    try {
      final created = await _repository.createHotel(hotel);
      _hotels = [created, ..._hotels];
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteHotel(String hotelId) async {
    try {
      await _repository.deleteHotel(hotelId);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    _hotels = _hotels.where((h) => h.hotelId != hotelId).toList();
    if (_selectedStartHotel?.hotelId == hotelId) _selectedStartHotel = null;
    if (_selectedEndHotel?.hotelId == hotelId) _selectedEndHotel = null;
    notifyListeners();
    return true;
  }

  void selectStartHotel(HotelModel hotel) {
    _selectedStartHotel = hotel;
    notifyListeners();
  }

  void selectEndHotel(HotelModel hotel) {
    _selectedEndHotel = hotel;
    notifyListeners();
  }

  void clearSelection() {
    _selectedStartHotel = null;
    _selectedEndHotel = null;
    notifyListeners();
  }

  Future<void> searchHotels(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _searchState = ViewState.idle;
      notifyListeners();
      return;
    }

    _searchState = ViewState.loading;
    _searchErrorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _repository.searchHotels(query);
      _searchState = ViewState.success;
    } on ApiException catch (e) {
      _searchState = ViewState.error;
      _searchErrorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    _searchState = ViewState.idle;
    _searchErrorMessage = null;
    notifyListeners();
  }

  Future<String?> reverseGeocode(double latitude, double longitude) {
    return _repository.reverseGeocode(latitude, longitude);
  }
}
