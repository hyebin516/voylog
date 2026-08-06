import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/screens/signup_email_screen.dart';

class FakeAuthRepository extends AuthRepository {
  ApiException? requestOtpError;
  String? lastOtpEmail;

  @override
  Future<void> requestSignupOtp(String email) async {
    lastOtpEmail = email;
    if (requestOtpError != null) throw requestOtpError!;
  }
}

Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const SignupEmailScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('otp screen'))),
    ),
  );
}

void main() {
  testWidgets('tapping the button with an empty email shows an inline error and does not call the repository', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.tap(find.text('인증번호 받기'));
    await tester.pump();

    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
    expect(repository.lastOtpEmail, isNull);
  });

  testWidgets('requesting an OTP successfully navigates to the OTP screen', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('signupEmailField')), 'a@b.com');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();

    expect(repository.lastOtpEmail, 'a@b.com');
    expect(find.text('otp screen'), findsOneWidget);
  });

  testWidgets('shows an error view when the email is already registered', (tester) async {
    final repository = FakeAuthRepository()
      ..requestOtpError = const ApiException(code: 'EMAIL_EXISTS', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('signupEmailField')), 'a@b.com');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 가입된 이메일입니다.'), findsOneWidget);
  });
}
