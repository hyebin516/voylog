import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/signup_screen.dart';
import 'package:travel_youtube_app/widgets/error_view.dart';

import 'fakes/fake_push_registration.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeAuthRepository extends AuthRepository {
  ApiException? requestOtpError;
  ApiException? signupError;
  Set<String> takenNicknames = {};
  String? lastOtpEmail;
  String? lastPassword;
  String? lastNickname;

  ApiException? nicknameCheckError;

  @override
  Future<bool> checkNicknameAvailable(String nickname) async {
    if (nicknameCheckError != null) throw nicknameCheckError!;
    return !takenNicknames.contains(nickname);
  }

  @override
  Future<void> requestSignupOtp(String email) async {
    lastOtpEmail = email;
    if (requestOtpError != null) throw requestOtpError!;
  }

  @override
  Future<UserModel> signup({required String email, required String password, required String nickname}) async {
    lastPassword = password;
    lastNickname = nickname;
    if (signupError != null) throw signupError!;
    return _user;
  }
}

/// Stands in for the real [SignupOtpScreen] pushed at `AppRoutes.signupOtp`
/// -- tapping "확인" pops with `true`, simulating a completed verification
/// without depending on the OTP screen's own implementation.
Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const SignupScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.signupOtp) {
          // Typed like the real OTP route: the screen awaits pushNamed<bool>.
          return MaterialPageRoute<bool>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인'),
              ),
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Text('home screen')), settings: settings);
      },
    ),
  );
}

Future<void> _checkNickname(WidgetTester tester, String nickname) async {
  await tester.enterText(find.byKey(const Key('signupNicknameField')), nickname);
  await tester.tap(find.byKey(const Key('checkNicknameButton')));
  await tester.pumpAndSettle();
}

Future<void> _verifyEmail(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('signupEmailField')), 'a@b.com');
  await tester.tap(find.text('인증하기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('확인'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an inline error for a missing nickname', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('a free nickname says so, not just a checkmark', (tester) async {
    // The check used to speak up only when a nickname was taken, so a free
    // one was indistinguishable from the button doing nothing.
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');

    expect(find.text('사용할 수 있는 닉네임이에요'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
  });

  testWidgets('editing the nickname clears the previous verdict', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    expect(find.text('사용할 수 있는 닉네임이에요'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Nagyeong2');
    await tester.pump();

    expect(find.text('사용할 수 있는 닉네임이에요'), findsNothing);
  });

  testWidgets('a failed check says it failed rather than claiming either way', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..nicknameCheckError = const ApiException(code: 'SERVER_ERROR', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');

    expect(find.text('사용할 수 있는 닉네임이에요'), findsNothing);
    expect(find.textContaining('이미 사용 중인'), findsNothing);
  });

  testWidgets('shows an inline message when the nickname is already taken', (tester) async {
    final repository = FakeAuthRepository()..takenNicknames.add('Nagyeong');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');

    expect(find.text('이미 사용 중인 닉네임이에요. 다른 닉네임을 입력해주세요'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('blocks signup until the nickname is checked', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Nagyeong');
    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('닉네임 중복 확인을 해주세요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('blocks signup until the email is verified', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('이메일 인증을 완료해 주세요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('checking, verifying, and filling in every field enables signup', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await _verifyEmail(tester);
    expect(repository.lastOtpEmail, 'a@b.com');

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'password123');
    await tester.tap(find.byKey(const Key('signupTermsCheckbox')));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(repository.lastPassword, 'password123');
    expect(repository.lastNickname, 'Nagyeong');
    expect(find.text('home screen'), findsOneWidget);
  });

  testWidgets('editing the nickname after checking it requires re-checking', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Different');
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byKey(const Key('checkNicknameButton')), findsOneWidget);
  });

  testWidgets('shows an inline error for a password shorter than 8 characters', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await _verifyEmail(tester);
    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'short');
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('비밀번호는 8자 이상 입력해 주세요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('shows an inline error when the password confirmation does not match', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await _verifyEmail(tester);
    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'different123');
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('shows an inline error when the terms checkbox is not checked', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await _verifyEmail(tester);
    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'password123');
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('이용약관에 동의해 주세요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('an already-registered email is reported under that field', (
    tester,
  ) async {
    final repository = FakeAuthRepository()..requestOtpError = const ApiException(code: 'EMAIL_EXISTS', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await tester.enterText(find.byKey(const Key('signupEmailField')), 'a@b.com');
    await tester.tap(find.text('인증하기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 가입된 이메일입니다.'), findsOneWidget);
    // Beside the field it belongs to, not in the generic box at the foot.
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('editing the email clears the already-registered verdict', (
    tester,
  ) async {
    final repository = FakeAuthRepository()..requestOtpError = const ApiException(code: 'EMAIL_EXISTS', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await tester.enterText(find.byKey(const Key('signupEmailField')), 'a@b.com');
    await tester.tap(find.text('인증하기'));
    await tester.pumpAndSettle();
    expect(find.text('이미 가입된 이메일입니다.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('signupEmailField')), 'different@b.com');
    await tester.pumpAndSettle();

    expect(find.text('이미 가입된 이메일입니다.'), findsNothing);
  });

  testWidgets('a verified email says so', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _verifyEmail(tester);

    expect(find.text('인증된 이메일이에요'), findsOneWidget);
  });

  testWidgets('shows an error view when signup fails server-side', (tester) async {
    final repository = FakeAuthRepository()..signupError = const ApiException(code: 'OTP_NOT_VERIFIED', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await _verifyEmail(tester);
    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'password123');
    await tester.tap(find.byKey(const Key('signupTermsCheckbox')));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('이메일 인증을 먼저 완료해 주세요.'), findsOneWidget);
  });

  testWidgets('a nickname the server rejects is reported under that field', (
    tester,
  ) async {
    // The duplicate check can pass and the name still be gone by the time
    // signup runs -- someone else took it in between. That verdict belongs
    // beside the nickname, not in a generic box at the foot of the form.
    final repository = FakeAuthRepository()
      ..signupError = const ApiException(code: 'NICKNAME_EXISTS', message: 'taken');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await _checkNickname(tester, 'Nagyeong');
    await _verifyEmail(tester);
    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'password123');
    await tester.tap(find.byKey(const Key('signupTermsCheckbox')));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    // It replaces the stale "사용할 수 있는" verdict rather than sitting
    // next to it, and the foot of the form stays quiet.
    expect(find.text('사용할 수 있는 닉네임이에요'), findsNothing);
    expect(find.byType(ErrorView), findsNothing);
  });
}
