import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/hotel_model.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/models/start_point_model.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/providers/hotel_provider.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/repositories/hotel_repository.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/walking_course_region_screen.dart';
import 'package:travel_youtube_app/widgets/primary_button.dart';
import 'helpers/phone_viewport.dart';

const WalkingCourseModel _emptyResult = WalkingCourseModel(
  course: null,
  recommendations: [],
);

class FakeWalkingCourseRepository extends WalkingCourseRepository {
  String? lastRegion;
  String? lastMood;
  String? lastWalkDuration;
  StartPointModel? lastStartPoint;
  List<String> lastAvoidPlaceIds = const [];

  @override
  Future<WalkingCourseModel> generate({
    required String region,
    required DateTime localTime,
    String? mood,
    String? walkDuration,
    StartPointModel? startPoint,
    List<String> avoidPlaceIds = const [],
  }) async {
    lastRegion = region;
    lastMood = mood;
    lastWalkDuration = walkDuration;
    lastStartPoint = startPoint;
    lastAvoidPlaceIds = avoidPlaceIds;
    return _emptyResult;
  }
}

const HotelModel _savedHotel = HotelModel(
  hotelId: 'h1',
  name: '전주 호텔',
  address: '전주시 어딘가',
  latitude: 35.81,
  longitude: 127.15,
);

class FakeHotelRepository extends HotelRepository {
  @override
  Future<List<HotelModel>> listHotels() async => [_savedHotel];
}

class FakeAuthRepository extends AuthRepository {
  @override
  Future<UserModel> loginWithEmail(String email, String password) async {
    return const UserModel(
      userId: 'u1',
      email: 'a@b.com',
      nickname: 'Nagyeong',
      profileImage: null,
    );
  }
}

Widget _wrap(
  WalkingCourseProvider provider, {
  AuthProvider? authProvider,
  HotelProvider? hotelProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider.value(
        value: authProvider ?? AuthProvider(repository: FakeAuthRepository()),
      ),
      ChangeNotifierProvider.value(
        value:
            hotelProvider ?? HotelProvider(repository: FakeHotelRepository()),
      ),
    ],
    child: MaterialApp(
      home: const WalkingCourseRegionScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => settings.name == AppRoutes.startPointPicker
            // Stands in for the map picker: pops with a chosen point.
            ? Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    const StartPointModel(name: '성수역', latitude: 37.5446, longitude: 127.0559),
                  ),
                  child: const Text('pick-start-point'),
                ),
              )
            : Scaffold(body: Text('route:${settings.name}')),
        settings: settings,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'shows every fixed region and disables the button until one is picked',
    (tester) async {
    usePhoneViewport(tester);
      await tester.pumpWidget(
        _wrap(WalkingCourseProvider(repository: FakeWalkingCourseRepository())),
      );

      expect(find.text('전주 한옥마을'), findsOneWidget);
      expect(find.text('서울 성수'), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'selecting a region enables the button, generates the course, and navigates to the result screen',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeWalkingCourseRepository();
      await tester.pumpWidget(
        _wrap(WalkingCourseProvider(repository: repository)),
      );

      await tester.ensureVisible(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.tap(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
      await tester.tap(find.byKey(const Key('generateCourseButton')));
      await tester.pumpAndSettle();

      expect(repository.lastRegion, '전주 한옥마을');
      expect(
        find.text('route:${AppRoutes.walkingCourseResult}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selecting a mood and walking-duration chip forwards them to the repository',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeWalkingCourseRepository();
      await tester.pumpWidget(
        _wrap(WalkingCourseProvider(repository: repository)),
      );

      await tester.ensureVisible(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.tap(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.ensureVisible(find.text('힙한'));
      await tester.tap(find.text('힙한'));
      await tester.ensureVisible(find.text('2~3시간'));
      await tester.tap(find.text('2~3시간'));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
      await tester.tap(find.byKey(const Key('generateCourseButton')));
      await tester.pumpAndSettle();

      expect(repository.lastMood, '힙한');
      expect(repository.lastWalkDuration, '2~3시간');
    },
  );

  testWidgets('tapping a selected mood chip again deselects it', (
    tester,
  ) async {
    final repository = FakeWalkingCourseRepository();
    await tester.pumpWidget(
      _wrap(WalkingCourseProvider(repository: repository)),
    );

    await tester.ensureVisible(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
    await tester.tap(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
    await tester.ensureVisible(find.text('힙한'));
    await tester.tap(find.text('힙한'));
    await tester.pump();
    await tester.ensureVisible(find.text('힙한'));
    await tester.tap(find.text('힙한'));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
    await tester.tap(find.byKey(const Key('generateCourseButton')));
    await tester.pumpAndSettle();

    expect(repository.lastMood, isNull);
  });

  testWidgets('hides the hotel picker for a logged-out user', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _wrap(WalkingCourseProvider(repository: FakeWalkingCourseRepository())),
    );

    expect(find.byKey(const Key('walkingCourseHotelPicker')), findsNothing);
  });

  testWidgets(
    'a chosen start point is sent with the request',
    (tester) async {
      usePhoneViewport(tester);
      final repository = FakeWalkingCourseRepository();
      await tester.pumpWidget(_wrap(WalkingCourseProvider(repository: repository)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('walkingCourseStartPointPicker')));
      await tester.tap(find.byKey(const Key('walkingCourseStartPointPicker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pick-start-point'));
      await tester.pumpAndSettle();

      // The tile now shows the chosen point instead of the prompt.
      expect(find.text('성수역'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.tap(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
      await tester.tap(find.byKey(const Key('generateCourseButton')));
      await tester.pumpAndSettle();

      expect(repository.lastStartPoint?.name, '성수역');
      expect(repository.lastStartPoint?.latitude, 37.5446);
    },
  );

  testWidgets(
    'generates without a start point when the user skips the picker',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeWalkingCourseRepository();
      final authProvider = AuthProvider(repository: FakeAuthRepository());
      await authProvider.loginWithEmail('a@b.com', 'password123');

      await tester.pumpWidget(
        _wrap(
          WalkingCourseProvider(repository: repository),
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.tap(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
      await tester.tap(find.byKey(const Key('generateCourseButton')));
      await tester.pumpAndSettle();

      expect(repository.lastRegion, '전주 한옥마을');
      expect(repository.lastStartPoint, isNull);
    },
  );

  testWidgets('a typed region is used for generation', (tester) async {
    usePhoneViewport(tester);
    final repository = FakeWalkingCourseRepository();
    await tester.pumpWidget(
      _wrap(WalkingCourseProvider(repository: repository)),
    );

    await tester.enterText(
      find.byKey(const Key('walkingCourseCustomRegionField')),
      '통영 강구안',
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
    await tester.tap(find.byKey(const Key('generateCourseButton')));
    await tester.pumpAndSettle();

    expect(repository.lastRegion, '통영 강구안');
  });

  testWidgets('a typed region overrides a previously selected chip', (
    tester,
  ) async {
    final repository = FakeWalkingCourseRepository();
    await tester.pumpWidget(
      _wrap(WalkingCourseProvider(repository: repository)),
    );

    await tester.ensureVisible(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
    await tester.tap(find.byKey(const Key('walkingCourseRegion_전주 한옥마을')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('walkingCourseCustomRegionField')),
      '통영 강구안',
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
    await tester.tap(find.byKey(const Key('generateCourseButton')));
    await tester.pumpAndSettle();

    expect(repository.lastRegion, '통영 강구안');
  });

  testWidgets('selecting a chip clears a typed region', (tester) async {
    usePhoneViewport(tester);
    final repository = FakeWalkingCourseRepository();
    await tester.pumpWidget(
      _wrap(WalkingCourseProvider(repository: repository)),
    );

    await tester.enterText(
      find.byKey(const Key('walkingCourseCustomRegionField')),
      '통영 강구안',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('walkingCourseRegion_서울 성수')));
    await tester.tap(find.byKey(const Key('walkingCourseRegion_서울 성수')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('generateCourseButton')));
    await tester.tap(find.byKey(const Key('generateCourseButton')));
    await tester.pumpAndSettle();

    expect(repository.lastRegion, '서울 성수');
  });
}
