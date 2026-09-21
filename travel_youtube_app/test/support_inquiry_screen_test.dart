import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/support_inquiry_model.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/providers/support_inquiry_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/repositories/support_inquiry_repository.dart';
import 'package:travel_youtube_app/screens/support_inquiry_screen.dart';

import 'fakes/fake_push_registration.dart';

const _user = UserModel(userId: 'u1', email: 'me@example.com', nickname: '혜빈', profileImage: null);

SupportInquiryModel _inquiry(String message) => SupportInquiryModel(
      inquiryId: 'i1',
      email: 'me@example.com',
      category: SupportInquiryCategory.bug,
      message: message,
      createdAt: DateTime(2026, 9, 21),
    );

class FakeSupportInquiryRepository implements SupportInquiryRepository {
  List<SupportInquiryModel> listResult = [];
  ApiException? submitError;
  ({String email, SupportInquiryCategory category, String message})? lastSubmit;

  @override
  Future<List<SupportInquiryModel>> listMine() async => listResult;

  @override
  Future<SupportInquiryModel> submit({
    required String email,
    required SupportInquiryCategory category,
    required String message,
  }) async {
    lastSubmit = (email: email, category: category, message: message);
    if (submitError != null) throw submitError!;
    return _inquiry(message);
  }
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.user});

  final UserModel? user;

  @override
  Future<bool> hasValidSession() async => user != null;

  @override
  Future<UserModel> fetchProfile() async => user!;
}

Future<AuthProvider> _authProvider({UserModel? user}) async {
  final provider = AuthProvider(
    repository: FakeAuthRepository(user: user),
    pushRegistration: fakePushRegistration(),
  );
  if (user != null) await provider.restoreSession();
  return provider;
}

Widget _wrap(AuthProvider auth, SupportInquiryProvider inquiries) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: inquiries),
    ],
    child: const MaterialApp(home: SupportInquiryScreen()),
  );
}

void main() {
  testWidgets('prefills the logged-in user\'s email and loads their history', (tester) async {
    final repository = FakeSupportInquiryRepository()..listResult = [_inquiry('예전 문의')];
    final auth = await _authProvider(user: _user);

    await tester.pumpWidget(_wrap(auth, SupportInquiryProvider(repository: repository)));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(find.byKey(const Key('inquiryEmailField')));
    expect(emailField.controller?.text, 'me@example.com');

    // The history sits below the form, and the ListView only builds what
    // is on screen.
    await tester.dragUntilVisible(find.text('예전 문의'), find.byType(ListView), const Offset(0, -200));
    expect(find.text('예전 문의'), findsOneWidget);
  });

  testWidgets('a guest gets an empty email field and no history section', (tester) async {
    final auth = await _authProvider();

    await tester.pumpWidget(_wrap(auth, SupportInquiryProvider(repository: FakeSupportInquiryRepository())));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(find.byKey(const Key('inquiryEmailField')));
    expect(emailField.controller?.text, isEmpty);
    expect(find.text('내 문의 내역'), findsNothing);
  });

  testWidgets('will not send an empty message', (tester) async {
    final repository = FakeSupportInquiryRepository();
    final auth = await _authProvider(user: _user);

    await tester.pumpWidget(_wrap(auth, SupportInquiryProvider(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitInquiryButton')));
    await tester.pumpAndSettle();

    expect(repository.lastSubmit, isNull);
    expect(find.text('문의 내용을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('sends the chosen category with the message and confirms', (tester) async {
    final repository = FakeSupportInquiryRepository();
    final auth = await _authProvider(user: _user);

    await tester.pumpWidget(_wrap(auth, SupportInquiryProvider(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_route')));
    await tester.enterText(find.byKey(const Key('inquiryMessageField')), '동선이 이상해요');
    await tester.tap(find.byKey(const Key('submitInquiryButton')));
    await tester.pumpAndSettle();

    expect(repository.lastSubmit?.category, SupportInquiryCategory.route);
    expect(repository.lastSubmit?.message, '동선이 이상해요');
    expect(find.textContaining('문의가 접수되었어요'), findsOneWidget);
  });

  testWidgets('shows why it failed instead of pretending it was sent', (tester) async {
    final repository = FakeSupportInquiryRepository()
      ..submitError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');
    final auth = await _authProvider(user: _user);

    await tester.pumpWidget(_wrap(auth, SupportInquiryProvider(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('inquiryMessageField')), '분석이 멈춰요');
    await tester.tap(find.byKey(const Key('submitInquiryButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('문의가 접수되었어요'), findsNothing);
  });
}
