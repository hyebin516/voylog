import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart';
import '../models/api_exception.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../utils/view_state.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthProvider({AuthRepository? repository}) : _repository = repository ?? AuthRepository() {
    DioClient().onUnauthorized = _handleUnauthorized;
  }

  ViewState _state = ViewState.idle;
  UserModel? _currentUser;
  String? _errorMessage;

  ViewState get state => _state;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> restoreSession() async {
    final hasSession = await _repository.hasValidSession();
    if (!hasSession) return false;

    try {
      _currentUser = await _repository.fetchProfile();
      _state = ViewState.success;
      notifyListeners();
      return true;
    } on ApiException {
      await _repository.logout();
      return false;
    }
  }

  Future<void> loginWithKakao(String kakaoAccessToken) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.loginWithKakao(kakaoAccessToken);
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    _state = ViewState.idle;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    try {
      await _repository.deleteAccount();
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    _currentUser = null;
    _state = ViewState.idle;
    notifyListeners();
    return true;
  }

  void _handleUnauthorized() {
    _currentUser = null;
    _state = ViewState.idle;
    notifyListeners();
  }
}
