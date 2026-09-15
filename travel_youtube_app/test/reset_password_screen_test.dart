import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/screens/reset_password_screen.dart';

class FakeAuthRepository extends AuthRepository {
  ApiException? resetError;
  String? lastEmail;
  String? lastNewPassword;

  @override
  Future<void> resetPassword({required String email, required String newPassword}) async {
    lastEmail = email;
    lastNewPassword = newPassword;
    if (resetError != null) throw resetError!;
  }
}

Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const ResetPasswordScreen(email: 'a@b.com'),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        settings: settings,
      ),
    ),
  );
}

void main() {
  testWidgets('shows an inline error for a password shorter than 8 characters', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('resetPasswordField')), 'short');
    await tester.enterText(find.byKey(const Key('resetPasswordConfirmField')), 'short');
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pump();

    expect(find.text('비밀번호는 8자 이상 입력해 주세요.'), findsOneWidget);
    expect(repository.lastEmail, isNull);
  });

  testWidgets('shows an inline error when the confirmation does not match', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('resetPasswordField')), 'new-password123');
    await tester.enterText(find.byKey(const Key('resetPasswordConfirmField')), 'different123');
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pump();

    expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
    expect(repository.lastEmail, isNull);
  });

  testWidgets('resetting successfully shows a confirmation dialog then returns to login', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('resetPasswordField')), 'new-password123');
    await tester.enterText(find.byKey(const Key('resetPasswordConfirmField')), 'new-password123');
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'a@b.com');
    expect(repository.lastNewPassword, 'new-password123');
    expect(find.text('비밀번호가 변경됐어요'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
  });

  testWidgets('shows an error view when the reset request fails', (tester) async {
    final repository = FakeAuthRepository()..resetError = const ApiException(code: 'OTP_NOT_VERIFIED', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('resetPasswordField')), 'new-password123');
    await tester.enterText(find.byKey(const Key('resetPasswordConfirmField')), 'new-password123');
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();

    expect(find.text('이메일 인증을 먼저 완료해 주세요.'), findsOneWidget);
  });
}
