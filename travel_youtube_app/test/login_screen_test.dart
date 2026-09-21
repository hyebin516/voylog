import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/screens/login_screen.dart';

import 'fakes/fake_push_registration.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeAuthRepository extends AuthRepository {
  UserModel? emailLoginResult;
  ApiException? emailLoginError;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<UserModel> loginWithEmail(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    if (emailLoginError != null) throw emailLoginError!;
    return emailLoginResult!;
  }
}

Widget _wrap(AuthProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const LoginScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => Scaffold(body: Text('route:${settings.name}'))),
    ),
  );
}

void main() {
  testWidgets('shows the email/password fields and both login options', (tester) async {
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository(), pushRegistration: fakePushRegistration())));

    expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
    expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('카카오로 3초만에 로그인'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
  });

  testWidgets('logging in with email/password authenticates the user', (tester) async {
    final repository = FakeAuthRepository()..emailLoginResult = _user;
    final authProvider = AuthProvider(repository: repository, pushRegistration: fakePushRegistration());
    await tester.pumpWidget(_wrap(authProvider));

    await tester.enterText(find.byKey(const Key('loginEmailField')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'password123');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'a@b.com');
    expect(repository.lastPassword, 'password123');
    expect(authProvider.isAuthenticated, isTrue);
  });

  testWidgets('shows an error view for invalid credentials', (tester) async {
    final repository = FakeAuthRepository()
      ..emailLoginError = const ApiException(code: 'INVALID_CREDENTIALS', message: 'boom');
    await tester.pumpWidget(_wrap(AuthProvider(repository: repository, pushRegistration: fakePushRegistration())));

    await tester.enterText(find.byKey(const Key('loginEmailField')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'wrong-password');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
  });

  testWidgets('tapping 회원가입 navigates to the signup route', (tester) async {
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository(), pushRegistration: fakePushRegistration())));

    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    expect(find.text('route:/signup'), findsOneWidget);
  });

  testWidgets('tapping 비밀번호를 잊으셨나요 navigates to the forgot-password route', (tester) async {
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository(), pushRegistration: fakePushRegistration())));

    await tester.tap(find.text('비밀번호를 잊으셨나요?'));
    await tester.pumpAndSettle();

    expect(find.text('route:/forgot-password'), findsOneWidget);
  });
}
