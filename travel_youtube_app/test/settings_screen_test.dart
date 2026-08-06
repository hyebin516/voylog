import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/notification_settings_model.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/providers/notification_settings_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/repositories/notification_settings_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeAuthRepository extends AuthRepository {
  ApiException? deleteAccountError;
  int deleteAccountCallCount = 0;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    if (deleteAccountError != null) throw deleteAccountError!;
  }

  @override
  Future<UserModel> loginWithKakao(String kakaoAccessToken) async => _user;
}

class FakeNotificationSettingsRepository extends NotificationSettingsRepository {
  @override
  Future<NotificationSettingsModel> getSettings() async =>
      const NotificationSettingsModel(tripAlerts: true, serviceAlerts: true, marketingAlerts: false);
}

Widget _wrap(AuthProvider provider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider(
        create: (_) => NotificationSettingsProvider(repository: FakeNotificationSettingsRepository()),
      ),
    ],
    child: MaterialApp(
      initialRoute: AppRoutes.settings,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    ),
  );
}

void main() {
  testWidgets('shows app info and a 회원 탈퇴 entry', (tester) async {
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository())));

    expect(find.text('Voylog'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
  });

  testWidgets('tapping 알림 설정 navigates to the notification settings screen', (tester) async {
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository())));

    await tester.tap(find.text('알림 설정'));
    await tester.pumpAndSettle();

    expect(find.text('여행 일정 알림'), findsOneWidget);
  });

  testWidgets('cancelling the confirm dialog does not delete the account', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(find.textContaining('계속하시겠습니까'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(repository.deleteAccountCallCount, 0);
  });

  testWidgets('confirming deletion calls AuthProvider.deleteAccount', (tester) async {
    final repository = FakeAuthRepository();
    final authProvider = AuthProvider(repository: repository);
    await authProvider.loginWithKakao('kakao-token');
    await tester.pumpWidget(_wrap(authProvider));

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();

    expect(repository.deleteAccountCallCount, 1);
    expect(authProvider.isAuthenticated, isFalse);
  });

  testWidgets('shows an error dialog when deletion fails', (tester) async {
    final repository = FakeAuthRepository()..deleteAccountError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();

    expect(find.text('오류'), findsOneWidget);
  });
}
