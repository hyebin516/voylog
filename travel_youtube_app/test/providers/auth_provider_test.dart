import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeAuthRepository extends AuthRepository {
  bool sessionIsValid = false;
  UserModel? profileToReturn;
  ApiException? profileError;
  UserModel? loginResult;
  ApiException? loginError;
  int logoutCallCount = 0;
  ApiException? deleteAccountError;
  int deleteAccountCallCount = 0;

  ApiException? requestOtpError;
  String? lastOtpEmail;
  ApiException? verifyOtpError;
  String? lastVerifyEmail;
  String? lastVerifyCode;
  UserModel? signupResult;
  ApiException? signupError;
  UserModel? emailLoginResult;
  ApiException? emailLoginError;

  @override
  Future<bool> hasValidSession() async => sessionIsValid;

  @override
  Future<UserModel> fetchProfile() async {
    if (profileError != null) throw profileError!;
    return profileToReturn!;
  }

  @override
  Future<UserModel> loginWithKakao(String kakaoAccessToken) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    if (deleteAccountError != null) throw deleteAccountError!;
  }

  @override
  Future<void> requestSignupOtp(String email) async {
    lastOtpEmail = email;
    if (requestOtpError != null) throw requestOtpError!;
  }

  @override
  Future<void> verifySignupOtp(String email, String code) async {
    lastVerifyEmail = email;
    lastVerifyCode = code;
    if (verifyOtpError != null) throw verifyOtpError!;
  }

  @override
  Future<UserModel> signup({required String email, required String password, required String nickname}) async {
    if (signupError != null) throw signupError!;
    return signupResult!;
  }

  @override
  Future<UserModel> loginWithEmail(String email, String password) async {
    if (emailLoginError != null) throw emailLoginError!;
    return emailLoginResult!;
  }
}

void main() {
  late FakeAuthRepository repository;
  late AuthProvider provider;

  setUp(() {
    repository = FakeAuthRepository();
    provider = AuthProvider(repository: repository);
  });

  test('starts unauthenticated', () {
    expect(provider.isAuthenticated, isFalse);
    expect(provider.currentUser, isNull);
  });

  group('restoreSession', () {
    test('returns false without fetching a profile when there is no stored session', () async {
      repository.sessionIsValid = false;

      final restored = await provider.restoreSession();

      expect(restored, isFalse);
      expect(provider.isAuthenticated, isFalse);
    });

    test('restores the user when the stored session is valid', () async {
      repository.sessionIsValid = true;
      repository.profileToReturn = _user;

      final restored = await provider.restoreSession();

      expect(restored, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser, _user);
      expect(provider.state, ViewState.success);
    });

    test('logs out and returns false when the stored token is rejected by the backend', () async {
      repository.sessionIsValid = true;
      repository.profileError = const ApiException(code: 'JWT_EXPIRED', message: 'boom');

      final restored = await provider.restoreSession();

      expect(restored, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(repository.logoutCallCount, 1);
    });
  });

  group('loginWithKakao', () {
    test('authenticates the user on success', () async {
      repository.loginResult = _user;

      await provider.loginWithKakao('kakao-token');

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser, _user);
      expect(provider.state, ViewState.success);
    });

    test('sets an error state with a friendly message on failure', () async {
      repository.loginError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      await provider.loginWithKakao('kakao-token');

      expect(provider.state, ViewState.error);
      expect(provider.isAuthenticated, isFalse);
    });
  });

  test('logout clears the current user and calls the repository', () async {
    repository.loginResult = _user;
    await provider.loginWithKakao('kakao-token');

    await provider.logout();

    expect(provider.isAuthenticated, isFalse);
    expect(provider.state, ViewState.idle);
    expect(repository.logoutCallCount, 1);
  });

  test('a 401/403 signaled via DioClient.onUnauthorized logs the user out', () async {
    repository.loginResult = _user;
    await provider.loginWithKakao('kakao-token');
    expect(provider.isAuthenticated, isTrue);

    DioClient().onUnauthorized?.call();

    expect(provider.isAuthenticated, isFalse);
    expect(provider.state, ViewState.idle);
  });

  group('requestSignupOtp', () {
    test('returns true on success', () async {
      final result = await provider.requestSignupOtp('a@b.com');

      expect(result, isTrue);
      expect(repository.lastOtpEmail, 'a@b.com');
    });

    test('returns false and sets an error message on failure', () async {
      repository.requestOtpError = const ApiException(code: 'EMAIL_EXISTS', message: 'boom');

      final result = await provider.requestSignupOtp('a@b.com');

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('verifySignupOtp', () {
    test('returns true on success', () async {
      final result = await provider.verifySignupOtp('a@b.com', '123456');

      expect(result, isTrue);
      expect(repository.lastVerifyEmail, 'a@b.com');
      expect(repository.lastVerifyCode, '123456');
    });

    test('returns false and sets an error message on failure', () async {
      repository.verifyOtpError = const ApiException(code: 'OTP_INVALID', message: 'boom');

      final result = await provider.verifySignupOtp('a@b.com', '000000');

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('signup', () {
    test('authenticates the user on success', () async {
      repository.signupResult = _user;

      final result = await provider.signup(email: 'a@b.com', password: 'password123', nickname: 'Nagyeong');

      expect(result, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser, _user);
    });

    test('returns false and sets an error message on failure', () async {
      repository.signupError = const ApiException(code: 'OTP_NOT_VERIFIED', message: 'boom');

      final result = await provider.signup(email: 'a@b.com', password: 'password123', nickname: 'Nagyeong');

      expect(result, isFalse);
      expect(provider.isAuthenticated, isFalse);
    });
  });

  group('loginWithEmail', () {
    test('authenticates the user on success', () async {
      repository.emailLoginResult = _user;

      await provider.loginWithEmail('a@b.com', 'password123');

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser, _user);
      expect(provider.state, ViewState.success);
    });

    test('sets an error state with a friendly message on failure', () async {
      repository.emailLoginError = const ApiException(code: 'INVALID_CREDENTIALS', message: 'boom');

      await provider.loginWithEmail('a@b.com', 'wrong-password');

      expect(provider.state, ViewState.error);
      expect(provider.isAuthenticated, isFalse);
    });
  });

  group('deleteAccount', () {
    test('clears the current user and returns true on success', () async {
      repository.loginResult = _user;
      await provider.loginWithKakao('kakao-token');

      final result = await provider.deleteAccount();

      expect(result, isTrue);
      expect(repository.deleteAccountCallCount, 1);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.state, ViewState.idle);
    });

    test('keeps the user logged in and returns false on failure', () async {
      repository.loginResult = _user;
      await provider.loginWithKakao('kakao-token');
      repository.deleteAccountError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      final result = await provider.deleteAccount();

      expect(result, isFalse);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.errorMessage, isNotNull);
    });
  });
}
