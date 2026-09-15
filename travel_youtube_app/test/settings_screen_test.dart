import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';

const UserModel _emailUser = UserModel(
  userId: 'u1',
  email: 'a@b.com',
  nickname: 'Nagyeong',
  profileImage: null,
  provider: 'email',
);

const UserModel _kakaoUser = UserModel(
  userId: 'u2',
  email: null,
  nickname: 'Kakao User',
  profileImage: null,
  provider: 'kakao',
);

class FakeAuthRepository extends AuthRepository {
  ApiException? deleteAccountError;
  ApiException? changePasswordError;
  ApiException? updateNicknameError;
  int deleteAccountCallCount = 0;
  String? lastCurrentPassword;
  String? lastNewPassword;
  UserModel loginUser = _emailUser;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    if (deleteAccountError != null) throw deleteAccountError!;
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    if (changePasswordError != null) throw changePasswordError!;
  }

  @override
  Future<UserModel> updateNickname(String nickname) async {
    if (updateNicknameError != null) throw updateNicknameError!;
    loginUser = UserModel(
      userId: loginUser.userId,
      email: loginUser.email,
      nickname: nickname,
      profileImage: loginUser.profileImage,
      provider: loginUser.provider,
    );
    return loginUser;
  }

  @override
  Future<UserModel> loginWithKakao(String kakaoAccessToken) async => loginUser;
}

Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      initialRoute: AppRoutes.settings,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    ),
  );
}

Future<AuthProvider> _loggedIn(WidgetTester tester, FakeAuthRepository repository, {UserModel? user}) async {
  repository.loginUser = user ?? _emailUser;
  final authProvider = AuthProvider(repository: repository);
  await authProvider.loginWithKakao('token');
  await tester.pumpWidget(_wrap(authProvider));
  await tester.pumpAndSettle();
  return authProvider;
}

void main() {
  testWidgets('shows the profile section and a 회원 탈퇴 entry', (tester) async {
    await _loggedIn(tester, FakeAuthRepository());

    expect(find.text('Nagyeong'), findsOneWidget);
    expect(find.text('a@b.com'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
  });

  testWidgets('shows a password-change row and 연동 안 됨 for an email account', (tester) async {
    await _loggedIn(tester, FakeAuthRepository());

    expect(find.text('비밀번호 변경'), findsOneWidget);
    expect(find.text('연동 안 됨'), findsOneWidget);
  });

  testWidgets('shows 연동됨 and no password-change row for a Kakao account', (tester) async {
    await _loggedIn(tester, FakeAuthRepository(), user: _kakaoUser);

    expect(find.text('비밀번호 변경'), findsNothing);
    expect(find.text('연동됨'), findsOneWidget);
  });

  testWidgets('editing the nickname calls AuthProvider.updateNickname', (tester) async {
    final repository = FakeAuthRepository();
    await _loggedIn(tester, repository);

    await tester.tap(find.text('Nagyeong'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('editNicknameField')), '새이름');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('새이름'), findsOneWidget);
  });

  testWidgets('changing the password calls AuthProvider.changePassword', (tester) async {
    final repository = FakeAuthRepository();
    await _loggedIn(tester, repository);

    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('currentPasswordField')), 'old-password');
    await tester.enterText(find.byKey(const Key('newPasswordField')), 'new-password123');
    await tester.enterText(find.byKey(const Key('newPasswordConfirmField')), 'new-password123');
    await tester.tap(find.text('변경'));
    await tester.pumpAndSettle();

    expect(repository.lastCurrentPassword, 'old-password');
    expect(repository.lastNewPassword, 'new-password123');
    expect(find.text('비밀번호를 변경했어요.'), findsOneWidget);
  });

  testWidgets('shows an inline error when the new password confirmation does not match', (tester) async {
    final repository = FakeAuthRepository();
    await _loggedIn(tester, repository);

    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('currentPasswordField')), 'old-password');
    await tester.enterText(find.byKey(const Key('newPasswordField')), 'new-password123');
    await tester.enterText(find.byKey(const Key('newPasswordConfirmField')), 'different123');
    await tester.tap(find.text('변경'));
    await tester.pump();

    expect(find.text('새 비밀번호가 일치하지 않아요.'), findsOneWidget);
    expect(repository.lastCurrentPassword, isNull);
  });

  testWidgets('cancelling the confirm dialog does not delete the account', (tester) async {
    final repository = FakeAuthRepository();
    await _loggedIn(tester, repository);

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(find.textContaining('계속하시겠습니까'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(repository.deleteAccountCallCount, 0);
  });

  testWidgets('confirming deletion calls AuthProvider.deleteAccount', (tester) async {
    final repository = FakeAuthRepository();
    final authProvider = await _loggedIn(tester, repository);

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();

    expect(repository.deleteAccountCallCount, 1);
    expect(authProvider.isAuthenticated, isFalse);
  });

  testWidgets('shows an error dialog when deletion fails', (tester) async {
    final repository = FakeAuthRepository()..deleteAccountError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');
    await _loggedIn(tester, repository);

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();

    expect(find.text('오류'), findsOneWidget);
  });
}
