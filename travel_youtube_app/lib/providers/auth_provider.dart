import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart';
import '../models/api_exception.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../services/push_registration_service.dart';
import '../utils/view_state.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final PushRegistrationService _pushRegistration;

  AuthProvider({AuthRepository? repository, PushRegistrationService? pushRegistration})
      : _repository = repository ?? AuthRepository(),
        _pushRegistration = pushRegistration ?? PushRegistrationService() {
    DioClient().onUnauthorized = _handleUnauthorized;
  }

  ViewState _state = ViewState.idle;
  UserModel? _currentUser;
  String? _errorMessage;
  String? _errorCode;

  ViewState get state => _state;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  /// The backend's error code for the last failure, so a screen can put the
  /// message beside the field it belongs to instead of at the foot of the
  /// form. Null unless the call that failed recorded one.
  String? get errorCode => _errorCode;
  bool get isLoading => _state == ViewState.loading;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> restoreSession() async {
    final hasSession = await _repository.hasValidSession();
    if (!hasSession) return false;

    try {
      _currentUser = await _repository.fetchProfile();
      _state = ViewState.success;
      notifyListeners();
      // FR-12: a returning session is a device the backend can push to.
      await _pushRegistration.registerDevice();
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
      await _pushRegistration.registerDevice();
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<bool> requestSignupOtp(String email) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.requestSignupOtp(email);
      _state = ViewState.idle;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifySignupOtp(String email, String code) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.verifySignupOtp(email, code);
      _state = ViewState.idle;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }

  Future<bool?> checkNicknameAvailable(String nickname) async {
    try {
      return await _repository.checkNicknameAvailable(nickname);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signup({required String email, required String password, required String nickname}) async {
    _state = ViewState.loading;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      _currentUser = await _repository.signup(email: email, password: password, nickname: nickname);
      _state = ViewState.success;
      notifyListeners();
      await _pushRegistration.registerDevice();
      return true;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
      _errorCode = e.code;
      notifyListeners();
      return false;
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.loginWithEmail(email, password);
      _state = ViewState.success;
      await _pushRegistration.registerDevice();
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    // Before the JWT goes: the request needs it, and this phone must stop
    // receiving the notifications of the account leaving it.
    await _pushRegistration.unregisterDevice();
    await _repository.logout();
    _currentUser = null;
    _state = ViewState.idle;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    await _pushRegistration.unregisterDevice();
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

  /// Returns whether it stuck, so the screen can confirm or show the error.
  Future<bool> updateProfileImage(String filePath) async {
    try {
      _currentUser = await _repository.uploadProfileImage(filePath);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  Future<bool> removeProfileImage() async {
    try {
      _currentUser = await _repository.removeProfileImage();
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  Future<bool> updateNickname(String nickname) async {
    try {
      _currentUser = await _repository.updateNickname(nickname);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      await _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  Future<bool> requestPasswordResetOtp(String email) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.requestPasswordResetOtp(email);
      _state = ViewState.idle;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPasswordResetOtp(String email, String code) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.verifyPasswordResetOtp(email, code);
      _state = ViewState.idle;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({required String email, required String newPassword}) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.resetPassword(email: email, newPassword: newPassword);
      _state = ViewState.idle;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }

  void _handleUnauthorized() {
    _currentUser = null;
    _state = ViewState.idle;
    notifyListeners();
  }
}
