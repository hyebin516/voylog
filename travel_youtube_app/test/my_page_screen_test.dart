import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/models/trip_model.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/providers/trip_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/repositories/trip_repository.dart';
import 'package:travel_youtube_app/screens/my_page_screen.dart';

import 'helpers/phone_viewport.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeAuthRepository extends AuthRepository {
  @override
  Future<UserModel> loginWithKakao(String kakaoAccessToken) async => _user;
}

class FakeTripRepository extends TripRepository {
  @override
  Future<List<TripModel>> listTrips() async => [];
}

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  @override
  Future<List<BookmarkFolderModel>> listFolders() async => [];
}

Future<AuthProvider> _authenticatedProvider() async {
  final authProvider = AuthProvider(repository: FakeAuthRepository());
  await authProvider.loginWithKakao('kakao-token');
  return authProvider;
}

Widget _wrap(AuthProvider authProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider(create: (_) => TripProvider(repository: FakeTripRepository())),
      ChangeNotifierProvider(create: (_) => BookmarkFolderProvider(repository: FakeBookmarkFolderRepository())),
    ],
    child: MaterialApp(
      home: const MyPageScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => Scaffold(body: Text('route:${settings.name}'))),
    ),
  );
}

void main() {
  testWidgets('shows the menu entries for a logged-in user, including logout/withdraw', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(await _authenticatedProvider()));
    await tester.pumpAndSettle();

    expect(find.text('Nagyeong'), findsOneWidget);
    expect(find.text('내 여행'), findsOneWidget);
    expect(find.text('북마크 폴더'), findsOneWidget);
    expect(find.text('계정 설정'), findsOneWidget);
    expect(find.text('취향 설정'), findsOneWidget);
    expect(find.text('취향 맞춤 추천'), findsOneWidget);
    expect(find.text('알림 설정'), findsOneWidget);
    expect(find.text('고객센터'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
    expect(find.text('로그인하기'), findsNothing);
  });

  testWidgets('shows a login prompt instead of logout/withdraw for a guest', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    expect(find.text('게스트'), findsOneWidget);
    expect(find.text('비회원으로 둘러보는 중'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
    expect(find.text('로그아웃'), findsNothing);
    expect(find.text('회원 탈퇴'), findsNothing);
  });

  testWidgets('tapping 로그인하기 as a guest navigates to the login route', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그인하기'));
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
  });

  testWidgets('tapping 취향 설정 navigates to the taste preferences route', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(await _authenticatedProvider()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취향 설정'));
    await tester.pumpAndSettle();

    expect(find.text('route:/taste-preferences'), findsOneWidget);
  });

  testWidgets('tapping 취향 맞춤 추천 navigates to the similar taste recommendations route', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(await _authenticatedProvider()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취향 맞춤 추천'));
    await tester.pumpAndSettle();

    expect(find.text('route:/recommendations/similar-taste'), findsOneWidget);
  });

  testWidgets('tapping 북마크 폴더 stat tile navigates to the bookmark folders route', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(await _authenticatedProvider()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('북마크 폴더'));
    await tester.pumpAndSettle();

    expect(find.text('route:/bookmark-folders'), findsOneWidget);
  });

  testWidgets('tapping 고객센터 navigates to the customer service route', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(await _authenticatedProvider()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();

    expect(find.text('route:/customer-service'), findsOneWidget);
  });
}
