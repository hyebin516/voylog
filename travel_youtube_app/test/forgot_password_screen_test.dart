import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/screens/forgot_password_screen.dart';

class FakeAuthRepository extends AuthRepository {
  ApiException? requestOtpError;
  String? lastEmail;

  @override
  Future<void> requestPasswordResetOtp(String email) async {
    lastEmail = email;
    if (requestOtpError != null) throw requestOtpError!;
  }
}

Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const ForgotPasswordScreen(),
      // Typed like the real OTP route: the screen awaits pushNamed<bool>.
      onGenerateRoute: (settings) => MaterialPageRoute<bool>(
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        settings: settings,
      ),
    ),
  );
}

void main() {
  testWidgets('shows an inline error for an empty email', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.tap(find.text('인증코드 받기'));
    await tester.pump();

    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
    expect(repository.lastEmail, isNull);
  });

  testWidgets('requesting a code navigates to the OTP route with the email', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('forgotPasswordEmailField')), 'a@b.com');
    await tester.tap(find.text('인증코드 받기'));
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'a@b.com');
    expect(find.text('route:/forgot-password/otp'), findsOneWidget);
  });

  testWidgets('shows an error view when the email is not registered', (tester) async {
    final repository = FakeAuthRepository()
      ..requestOtpError = const ApiException(code: 'EMAIL_NOT_FOUND', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('forgotPasswordEmailField')), 'nope@b.com');
    await tester.tap(find.text('인증코드 받기'));
    await tester.pumpAndSettle();

    expect(find.text('등록되지 않은 이메일이에요.'), findsOneWidget);
  });
}
