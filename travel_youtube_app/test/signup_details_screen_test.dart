import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/screens/signup_details_screen.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeAuthRepository extends AuthRepository {
  ApiException? signupError;
  String? lastPassword;
  String? lastNickname;

  @override
  Future<UserModel> signup({required String email, required String password, required String nickname}) async {
    lastPassword = password;
    lastNickname = nickname;
    if (signupError != null) throw signupError!;
    return _user;
  }
}

Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const SignupDetailsScreen(email: 'a@b.com'),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('home screen'))),
    ),
  );
}

void main() {
  testWidgets('shows an inline error for a password shorter than 8 characters', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'short');
    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Nagyeong');
    await tester.tap(find.text('회원가입 완료'));
    await tester.pump();

    expect(find.text('비밀번호는 8자 이상 입력해 주세요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('shows an inline error for a missing nickname', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.tap(find.text('회원가입 완료'));
    await tester.pump();

    expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('shows an inline error when the password confirmation does not match', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'different123');
    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Nagyeong');
    await tester.tap(find.text('회원가입 완료'));
    await tester.pump();

    expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('signing up successfully navigates to home and clears the stack', (tester) async {
    final repository = FakeAuthRepository();
    final authProvider = AuthProvider(repository: repository);
    await tester.pumpWidget(_wrap(authProvider));

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Nagyeong');
    await tester.tap(find.byKey(const Key('signupTermsCheckbox')));
    await tester.tap(find.text('회원가입 완료'));
    await tester.pumpAndSettle();

    expect(repository.lastPassword, 'password123');
    expect(repository.lastNickname, 'Nagyeong');
    expect(authProvider.isAuthenticated, isTrue);
    expect(find.text('home screen'), findsOneWidget);
  });

  testWidgets('shows an inline error when the terms checkbox is not checked', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Nagyeong');
    await tester.tap(find.text('회원가입 완료'));
    await tester.pump();

    expect(find.text('이용약관에 동의해 주세요.'), findsOneWidget);
    expect(repository.lastNickname, isNull);
  });

  testWidgets('shows an error view when the OTP was not verified', (tester) async {
    final repository = FakeAuthRepository()..signupError = const ApiException(code: 'OTP_NOT_VERIFIED', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository)));

    await tester.enterText(find.byKey(const Key('signupPasswordField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupPasswordConfirmField')), 'password123');
    await tester.enterText(find.byKey(const Key('signupNicknameField')), 'Nagyeong');
    await tester.tap(find.byKey(const Key('signupTermsCheckbox')));
    await tester.tap(find.text('회원가입 완료'));
    await tester.pumpAndSettle();

    expect(find.text('이메일 인증을 먼저 완료해 주세요.'), findsOneWidget);
  });
}
