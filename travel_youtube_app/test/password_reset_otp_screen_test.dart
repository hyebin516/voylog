import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/screens/password_reset_otp_screen.dart';

class FakeAuthRepository extends AuthRepository {
  ApiException? verifyOtpError;
  String? lastEmail;
  String? lastCode;

  @override
  Future<void> verifyPasswordResetOtp(String email, String code) async {
    lastEmail = email;
    lastCode = code;
    if (verifyOtpError != null) throw verifyOtpError!;
  }
}

Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final verified = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const PasswordResetOtpScreen(email: 'a@b.com')),
                );
                if (verified == true && context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: Text('verified'))));
                }
              },
              child: const Text('open otp'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows an inline error for a code shorter than 6 digits', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));
    await tester.tap(find.text('open otp'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('passwordResetOtpField')), '123');
    await tester.tap(find.text('인증 완료'));
    await tester.pump();

    expect(find.text('6자리 인증번호를 입력해 주세요.'), findsOneWidget);
    expect(repository.lastEmail, isNull);
  });

  testWidgets('verifying successfully pops back with the verified flag', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));
    await tester.tap(find.text('open otp'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('passwordResetOtpField')), '123456');
    await tester.tap(find.text('인증 완료'));
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'a@b.com');
    expect(repository.lastCode, '123456');
    expect(find.text('verified'), findsOneWidget);
  });

  testWidgets('shows an error view for an incorrect code', (tester) async {
    final repository = FakeAuthRepository()..verifyOtpError = const ApiException(code: 'OTP_INVALID', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));
    await tester.tap(find.text('open otp'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('passwordResetOtpField')), '000000');
    await tester.tap(find.text('인증 완료'));
    await tester.pumpAndSettle();

    expect(find.text('인증번호가 올바르지 않습니다.'), findsOneWidget);
  });
}
