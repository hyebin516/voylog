import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/hotel_model.dart';
import '../repositories/hotel_repository.dart';
import '../utils/view_state.dart';

class HotelProvider extends ChangeNotifier {
  final HotelRepository _repository;

  HotelProvider({HotelRepository? repository}) : _repository = repository ?? HotelRepository();

  ViewState _state = ViewState.idle;
  List<HotelModel> _hotels = [];
  String? _errorMessage;

  HotelModel? _selectedStartHotel;
  HotelModel? _selectedEndHotel;

  ViewState get state => _state;
  List<HotelModel> get hotels => _hotels;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  HotelModel? get selectedStartHotel => _selectedStartHotel;
  HotelModel? get selectedEndHotel => _selectedEndHotel;

  /// True when the user picked the same hotel for both endpoints.
  bool get isRoundTrip =>
      _selectedStartHotel != null && _selectedEndHotel != null && _selectedStartHotel!.hotelId == _selectedEndHotel!.hotelId;

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
}
