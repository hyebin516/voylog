import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
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
import 'package:travel_youtube_app/widgets/profile_avatar.dart';

import 'helpers/phone_viewport.dart';

import 'fakes/fake_image_picker_service.dart';
import 'fakes/fake_push_registration.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({UserModel user = _user}) : _loggedIn = user;

  UserModel _loggedIn;
  String? uploadedPath;
  int removeCount = 0;
  ApiException? uploadError;

  @override
  Future<UserModel> loginWithKakao(String kakaoAccessToken) async => _loggedIn;

  @override
  Future<UserModel> uploadProfileImage(String filePath) async {
    uploadedPath = filePath;
    if (uploadError != null) throw uploadError!;
    _loggedIn = UserModel(
      userId: _loggedIn.userId,
      email: _loggedIn.email,
      nickname: _loggedIn.nickname,
      profileImage: 'http://localhost:4000/uploads/profile-images/u1-new.jpg',
    );
    return _loggedIn;
  }

  @override
  Future<UserModel> removeProfileImage() async {
    removeCount += 1;
    _loggedIn = UserModel(
      userId: _loggedIn.userId,
      email: _loggedIn.email,
      nickname: _loggedIn.nickname,
      profileImage: null,
    );
    return _loggedIn;
  }
}

class FakeTripRepository extends TripRepository {
  @override
  Future<List<TripModel>> listTrips() async => [];
}

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  @override
  Future<List<BookmarkFolderModel>> listFolders() async => [];
}

Future<AuthProvider> _authenticatedProvider({UserModel user = _user}) async {
  final authProvider = AuthProvider(repository: FakeAuthRepository(user: user), pushRegistration: fakePushRegistration());
  await authProvider.loginWithKakao('kakao-token');
  return authProvider;
}

Widget _wrap(AuthProvider authProvider, {FakeImagePickerService? picker}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider(create: (_) => TripProvider(repository: FakeTripRepository())),
      ChangeNotifierProvider(create: (_) => BookmarkFolderProvider(repository: FakeBookmarkFolderRepository())),
    ],
    child: MaterialApp(
      home: MyPageScreen(imagePicker: picker ?? FakeImagePickerService()),
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

  testWidgets('a Kakao account without an email is not labelled as a non-member', (tester) async {
    // Kakao only returns an email when the user consented to sharing it, so
    // a signed-in Kakao user often has none -- and the guest line then said
    // they were just browsing without an account.
    usePhoneViewport(tester);
    const kakaoUser = UserModel(
      userId: 'u2',
      email: null,
      nickname: 'Kakao User',
      profileImage: null,
      provider: 'kakao',
    );
    await tester.pumpWidget(_wrap(await _authenticatedProvider(user: kakaoUser)));
    await tester.pumpAndSettle();

    expect(find.text('비회원으로 둘러보는 중'), findsNothing);
    expect(find.text('카카오 계정으로 로그인'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('shows a login prompt instead of logout/withdraw for a guest', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository(), pushRegistration: fakePushRegistration())));
    await tester.pumpAndSettle();

    expect(find.text('게스트'), findsOneWidget);
    expect(find.text('비회원으로 둘러보는 중'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
    expect(find.text('로그아웃'), findsNothing);
    expect(find.text('회원 탈퇴'), findsNothing);
  });

  testWidgets('tapping 로그인하기 as a guest navigates to the login route', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(AuthProvider(repository: FakeAuthRepository(), pushRegistration: fakePushRegistration())));
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

  group('the profile photo (Kakao 프로필 사진 동의항목)', () {
    testWidgets('hands the avatar the photo the account has', (tester) async {
      const withPhoto = UserModel(
        userId: 'u1',
        email: null,
        nickname: '혜빈',
        profileImage: 'https://k.kakaocdn.net/profile.jpg',
      );

      await tester.pumpWidget(_wrap(await _authenticatedProvider(user: withPhoto)));
      await tester.pumpAndSettle();

      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first);
      expect(avatar.imageUrl, 'https://k.kakaocdn.net/profile.jpg');
    });

    testWidgets('shows the fallback circle when the account has no photo', (tester) async {
      // A Kakao user who declined the photo consent item, or any email account.
      await tester.pumpWidget(_wrap(await _authenticatedProvider()));
      await tester.pumpAndSettle();

      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first);
      expect(avatar.imageUrl, isNull);
      expect(find.byIcon(Icons.person_rounded), findsWidgets);
    });
  });

  group('changing the profile photo from the gallery', () {
    const withPhoto = UserModel(
      userId: 'u1',
      email: null,
      nickname: '혜빈',
      profileImage: 'http://localhost:4000/uploads/profile-images/u1-old.jpg',
    );

    testWidgets('uploads the photo the user picked', (tester) async {
      usePhoneViewport(tester);
      final repository = FakeAuthRepository();
      final picker = FakeImagePickerService(pathToReturn: '/tmp/chosen.jpg');
      final auth = AuthProvider(repository: repository, pushRegistration: fakePushRegistration());
      await auth.loginWithKakao('kakao-token');

      await tester.pumpWidget(_wrap(auth, picker: picker));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileAvatarButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickPhotoTile')));
      await tester.pumpAndSettle();

      expect(picker.pickCount, 1);
      expect(repository.uploadedPath, '/tmp/chosen.jpg');
      expect(find.text('프로필 사진을 바꿨어요.'), findsOneWidget);
    });

    testWidgets('uploads nothing when the user backs out of the gallery', (tester) async {
      usePhoneViewport(tester);
      final repository = FakeAuthRepository();
      final picker = FakeImagePickerService(pathToReturn: null);
      final auth = AuthProvider(repository: repository, pushRegistration: fakePushRegistration());
      await auth.loginWithKakao('kakao-token');

      await tester.pumpWidget(_wrap(auth, picker: picker));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileAvatarButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickPhotoTile')));
      await tester.pumpAndSettle();

      expect(picker.pickCount, 1);
      expect(repository.uploadedPath, isNull);
    });

    testWidgets('offers removal only to someone who has a photo', (tester) async {
      usePhoneViewport(tester);
      final auth = AuthProvider(
        repository: FakeAuthRepository(user: withPhoto),
        pushRegistration: fakePushRegistration(),
      );
      await auth.loginWithKakao('kakao-token');

      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileAvatarButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('removePhotoTile')), findsOneWidget);
    });

    testWidgets('hides removal when the avatar is already the default', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(_wrap(await _authenticatedProvider()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileAvatarButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('removePhotoTile')), findsNothing);
    });

    testWidgets('clears the photo when removal is chosen', (tester) async {
      usePhoneViewport(tester);
      final repository = FakeAuthRepository(user: withPhoto);
      final auth = AuthProvider(repository: repository, pushRegistration: fakePushRegistration());
      await auth.loginWithKakao('kakao-token');

      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileAvatarButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('removePhotoTile')));
      await tester.pumpAndSettle();

      expect(repository.removeCount, 1);
      expect(auth.currentUser?.profileImage, isNull);
    });

    testWidgets('says why it failed instead of claiming success', (tester) async {
      usePhoneViewport(tester);
      final repository = FakeAuthRepository()
        ..uploadError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');
      final auth = AuthProvider(repository: repository, pushRegistration: fakePushRegistration());
      await auth.loginWithKakao('kakao-token');

      await tester.pumpWidget(_wrap(auth, picker: FakeImagePickerService()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileAvatarButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickPhotoTile')));
      await tester.pumpAndSettle();

      expect(find.text('프로필 사진을 바꿨어요.'), findsNothing);
    });

    testWidgets('a guest gets no photo button at all', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(_wrap(AuthProvider(
        repository: FakeAuthRepository(),
        pushRegistration: fakePushRegistration(),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileAvatarButton')), findsNothing);
    });
  });
}
