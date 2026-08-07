import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/location_result.dart';
import '../repositories/location_repository.dart';
import '../utils/view_state.dart';

class LocationProvider extends ChangeNotifier {
  final LocationRepository _repository;
  StreamSubscription<LocationResult>? _subscription;

  LocationProvider({LocationRepository? repository}) : _repository = repository ?? const GeolocatorLocationRepository();

  ViewState _state = ViewState.idle;
  LocationPermissionState? _permissionState;
  LocationResult? _currentLocation;
  String? _errorMessage;

  ViewState get state => _state;
  LocationPermissionState? get permissionState => _permissionState;
  LocationResult? get currentLocation => _currentLocation;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  /// Requests permission, fetches an initial fix, and then keeps
  /// [currentLocation] updated as the device moves. Call [stop] when the
  /// screen using this is no longer visible.
  Future<void> start() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    _permissionState = await _repository.checkAndRequestPermission();
    if (_permissionState != LocationPermissionState.granted) {
      _state = ViewState.error;
      _errorMessage = _permissionErrorMessage(_permissionState!);
      notifyListeners();
      return;
    }

    final location = await _repository.getCurrentLocation();
    if (location == null) {
      _state = ViewState.error;
      _errorMessage = '현재 위치를 가져오지 못했습니다.';
      notifyListeners();
      return;
    }

    _currentLocation = location;
    _state = ViewState.success;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository.watchPosition().listen((next) {
      _currentLocation = next;
      notifyListeners();
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  String _permissionErrorMessage(LocationPermissionState permission) {
    switch (permission) {
      case LocationPermissionState.serviceDisabled:
        return '위치 서비스가 꺼져 있습니다. 기기 설정에서 위치 서비스를 켜주세요.';
      case LocationPermissionState.deniedForever:
        return '위치 권한이 거부되었습니다. 앱 설정에서 위치 권한을 허용해 주세요.';
      case LocationPermissionState.denied:
        return '주변 추천을 이용하려면 위치 권한이 필요합니다.';
      case LocationPermissionState.granted:
        return '';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
