import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/trip_model.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/hotel_provider.dart';
import 'package:travel_youtube_app/providers/itinerary_provider.dart';
import 'package:travel_youtube_app/providers/trip_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/repositories/trip_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/trip_detail_screen.dart';

import 'fakes/fake_map_widget.dart';
import 'helpers/mock_secure_storage_channel.dart';

ItineraryModel _day(int dayNumber, {List<RoutePointModel> routeData = const []}) {
  return ItineraryModel(
    itineraryId: 'it-$dayNumber',
    tripId: 't1',
    dayNumber: dayNumber,
    startHotelId: 'h1',
    endHotelId: 'h1',
    routeType: 'roundTrip',
    optimizationPriority: 'duration',
    transportMode: 'car',
    totalDistanceM: 1000,
    totalDurationSec: 600,
    routeData: routeData,
  );
}

/// A located day: the hotel, then [places] in order, back to the hotel.
List<RoutePointModel> _route(List<String> places) => [
  const RoutePointModel(order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: '숙소', latitude: 35.93, longitude: 126.95),
  for (var i = 0; i < places.length; i++)
    RoutePointModel(order: i + 1, type: 'place', hotelId: null, placeId: places[i], name: places[i], latitude: 35.9 + i / 100, longitude: 126.9),
  RoutePointModel(order: places.length + 1, type: 'hotel', hotelId: 'h1', placeId: null, name: '숙소', latitude: 35.93, longitude: 126.95),
];

class FakeTripRepository extends TripRepository {
  TripDetailModel? tripDetailToReturn;
  ApiException? deleteError;
  final List<String> deleteCalls = [];

  @override
  Future<TripDetailModel> getTrip(String tripId) async => tripDetailToReturn!;

  @override
  Future<void> deleteTrip(String tripId) async {
    deleteCalls.add(tripId);
    if (deleteError != null) throw deleteError!;
  }

  final List<String> deleteDayCalls = [];

  /// What getTrip returns once a day was deleted (the server renumbers).
  TripDetailModel? tripAfterDayDelete;

  @override
  Future<void> deleteDay(String itineraryId) async {
    deleteDayCalls.add(itineraryId);
    if (tripAfterDayDelete != null) tripDetailToReturn = tripAfterDayDelete;
  }
}

class _NoFoldersRepository extends BookmarkFolderRepository {
  @override
  Future<List<BookmarkFolderModel>> listFolders() async => [];
}

Widget _wrap(TripProvider tripProvider, {bool fakeMap = false}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: tripProvider),
      ChangeNotifierProvider(create: (_) => HotelProvider()),
      ChangeNotifierProvider(create: (_) => ItineraryProvider()),
      ChangeNotifierProvider(create: (_) => BookmarkProvider()),
      // "날짜 추가" opens the day/folder picker, which lists bookmark folders.
      ChangeNotifierProvider(create: (_) => BookmarkFolderProvider(repository: _NoFoldersRepository())),
    ],
    child: MaterialApp(
      // `home:` builds the initial screen directly (AppRoutes.tripDetail
      // needs a `tripId` argument, which `initialRoute:` can't carry).
      // `onGenerateRoute:` is still wired so that in-app pushNamed calls
      // (e.g. "일차 추가" -> /bookmarks) resolve correctly.
      home: fakeMap ? const TripDetailScreen(tripId: 't1', mapRepository: FakeMapRepository()) : const TripDetailScreen(tripId: 't1'),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    ),
  );
}

void main() {
  setUpAll(installMockSecureStorageChannel);

  testWidgets('shows an empty state and a "날짜 추가" button when the trip has no days yet', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(tripId: 't1', name: '제주도 여행', createdAt: DateTime(2026, 1, 1), days: []);
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('제주도 여행'), findsOneWidget);
    expect(find.text('아직 저장된 일차가 없습니다.'), findsOneWidget);
    expect(find.text('날짜 추가'), findsOneWidget);
  });

  testWidgets('shows each saved day and offers to add the next one', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(
        tripId: 't1',
        name: '제주도 여행',
        createdAt: DateTime(2026, 1, 1),
        days: [_day(1), _day(2)],
      );
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('1일차'), findsOneWidget);
    expect(find.text('2일차'), findsOneWidget);
    expect(find.text('날짜 추가'), findsOneWidget);
  });

  testWidgets('tapping "날짜 추가" records the active trip/day on TripProvider', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(tripId: 't1', name: '제주도 여행', createdAt: DateTime(2026, 1, 1), days: [_day(1)]);
    final tripProvider = TripProvider(repository: repository);
    await tester.pumpWidget(_wrap(tripProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('날짜 추가'));
    await tester.pumpAndSettle();

    expect(tripProvider.activeTripId, 't1');
    expect(tripProvider.activeDayNumber, 2);
  });

  testWidgets('shows "전체 일정" even when the trip has no days yet', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(tripId: 't1', name: '제주도 여행', createdAt: DateTime(2026, 1, 1), days: []);
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('전체 일정'), findsOneWidget);
  });

  testWidgets('does not show a standalone "이미지로 공유" button (that lives on 전체 일정 now)', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(
        tripId: 't1',
        name: '제주도 여행',
        createdAt: DateTime(2026, 1, 1),
        days: [_day(1)],
      );
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('이미지로 공유'), findsNothing);
  });

  // Drawing every day at once laid two loops from the same hotel over each
  // other. The map shows one day: the first by default, the tapped one after.
  testWidgets('the map shows day 1 by default and only the tapped day after', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(
        tripId: 't1',
        name: '익산 1박 2일',
        createdAt: DateTime(2026, 1, 1),
        days: [
          _day(1, routeData: _route(['서동 시장', '대일분식'])),
          _day(2, routeData: _route(['미륵사지 석탑', '따봉식당'])),
        ],
      );
    await tester.pumpWidget(_wrap(TripProvider(repository: repository), fakeMap: true));
    await tester.pumpAndSettle();

    expect(find.text('marker:서동 시장'), findsOneWidget);
    expect(find.text('marker:미륵사지 석탑'), findsNothing);

    await tester.tap(find.text('2일차'));
    await tester.pumpAndSettle();

    expect(find.text('marker:미륵사지 석탑'), findsOneWidget);
    expect(find.text('marker:따봉식당'), findsOneWidget);
    expect(find.text('marker:서동 시장'), findsNothing);

    await tester.tap(find.text('1일차'));
    await tester.pumpAndSettle();

    expect(find.text('marker:서동 시장'), findsOneWidget);
    expect(find.text('marker:미륵사지 석탑'), findsNothing);
  });

  testWidgets('a day can be deleted after confirming, and the trip reloads renumbered', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(
        tripId: 't1',
        name: '익산 1박 2일',
        createdAt: DateTime(2026, 1, 1),
        days: [_day(1), _day(2)],
      )
      // After deleting day 1 the server moves day 2 up to day 1.
      ..tripAfterDayDelete = TripDetailModel(tripId: 't1', name: '익산 1박 2일', createdAt: DateTime(2026, 1, 1), days: [_day(1)]);
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('1일차 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('1일차 동선을 삭제하시겠습니까? 뒤의 날짜는 하루씩 앞당겨집니다.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(repository.deleteDayCalls, ['it-1']);
    expect(find.text('1일차'), findsOneWidget);
    expect(find.text('2일차'), findsNothing);
  });

  testWidgets('cancelling the confirmation keeps the day', (tester) async {
    final repository = FakeTripRepository()
      ..tripDetailToReturn = TripDetailModel(tripId: 't1', name: '익산', createdAt: DateTime(2026, 1, 1), days: [_day(1)]);
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('1일차 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(repository.deleteDayCalls, isEmpty);
    expect(find.text('1일차'), findsOneWidget);
  });
}
