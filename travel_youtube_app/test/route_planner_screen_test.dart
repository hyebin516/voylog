import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/hotel_model.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/trip_model.dart';
import 'package:travel_youtube_app/providers/hotel_provider.dart';
import 'package:travel_youtube_app/providers/itinerary_provider.dart';
import 'package:travel_youtube_app/providers/trip_provider.dart';
import 'package:travel_youtube_app/repositories/itinerary_repository.dart';
import 'package:travel_youtube_app/repositories/trip_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/hotel_search_screen.dart';
import 'package:travel_youtube_app/screens/route_planner_screen.dart';

import 'fakes/fake_map_widget.dart';

const HotelModel _hotelA = HotelModel(hotelId: 'h1', name: 'A호텔', address: 'addr a', latitude: 35.1, longitude: 129.1);
const HotelModel _hotelB = HotelModel(hotelId: 'h2', name: 'B호텔', address: 'addr b', latitude: 35.2, longitude: 129.2);

const ItineraryModel _optimizedResult = ItineraryModel(
  itineraryId: 'i1',
  tripId: 't1',
  dayNumber: 1,
  startHotelId: 'h1',
  endHotelId: 'h2',
  routeType: 'hotelToHotel',
  optimizationPriority: 'duration',
  transportMode: 'car',
  totalDistanceM: 4200,
  totalDurationSec: 1800,
  routeData: [
    RoutePointModel(order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: 'A호텔', latitude: 35.1, longitude: 129.1),
    RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '해운대해수욕장', latitude: 35.15, longitude: 129.16),
    RoutePointModel(order: 2, type: 'hotel', hotelId: 'h2', placeId: null, name: 'B호텔', latitude: 35.2, longitude: 129.2),
  ],
);

class FakeItineraryRepository extends ItineraryRepository {
  ItineraryModel? resultToReturn;
  ApiException? errorToThrow;
  Map<String, dynamic>? lastCall;

  @override
  Future<ItineraryModel> createItinerary({
    required String tripId,
    required int dayNumber,
    required String startHotelId,
    required String endHotelId,
    required List<String> placeIds,
    String transportMode = 'car',
  }) async {
    lastCall = {
      'tripId': tripId,
      'dayNumber': dayNumber,
      'startHotelId': startHotelId,
      'endHotelId': endHotelId,
      'placeIds': placeIds,
      'transportMode': transportMode,
    };
    if (errorToThrow != null) throw errorToThrow!;
    return resultToReturn!;
  }
}

class FakeTripRepository extends TripRepository {
  final List<String> loadCalls = [];

  @override
  Future<TripDetailModel> getTrip(String tripId) async {
    loadCalls.add(tripId);
    return TripDetailModel(tripId: tripId, name: '부산 여행', createdAt: DateTime(2026, 1, 1), days: const []);
  }
}

Widget _wrap({
  required HotelProvider hotelProvider,
  required ItineraryProvider itineraryProvider,
  required TripProvider tripProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: hotelProvider),
      ChangeNotifierProvider.value(value: itineraryProvider),
      ChangeNotifierProvider.value(value: tripProvider),
    ],
    child: MaterialApp(
      initialRoute: AppRoutes.tripDetail,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.tripDetail:
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.routePlanner),
                  child: const Text('go to route planner'),
                ),
              ),
              settings: settings,
            );
          case AppRoutes.routePlanner:
            return MaterialPageRoute(
              builder: (_) => RoutePlannerScreen(mapRepository: const FakeMapRepository()),
              settings: settings,
            );
          case AppRoutes.hotelSearch:
            final args = settings.arguments as HotelSearchScreenArgs;
            return MaterialPageRoute(
              builder: (_) => Scaffold(body: Text('hotel search: ${args.role}')),
              settings: settings,
            );
          default:
            return null;
        }
      },
    ),
  );
}

Future<void> _openRoutePlanner(WidgetTester tester) async {
  await tester.tap(find.text('go to route planner'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a placeholder when there is no active trip/day', (tester) async {
    await tester.pumpWidget(
      _wrap(hotelProvider: HotelProvider(), itineraryProvider: ItineraryProvider(), tripProvider: TripProvider()),
    );
    await _openRoutePlanner(tester);

    expect(find.text('여행 상세 화면에서 "일차 추가"를 눌러 시작해주세요.'), findsOneWidget);
  });

  testWidgets('tapping "시작 호텔" navigates to hotel search for the start role', (tester) async {
    final tripProvider = TripProvider()..startBuildingDay('t1', 1);

    await tester.pumpWidget(
      _wrap(hotelProvider: HotelProvider(), itineraryProvider: ItineraryProvider(), tripProvider: tripProvider),
    );
    await _openRoutePlanner(tester);

    await tester.tap(find.text('시작 호텔'));
    await tester.pumpAndSettle();
    expect(find.text('hotel search: HotelSelectionRole.start'), findsOneWidget);
  });

  testWidgets('tapping "종료 호텔" navigates to hotel search for the end role', (tester) async {
    final tripProvider = TripProvider()..startBuildingDay('t1', 1);

    await tester.pumpWidget(
      _wrap(hotelProvider: HotelProvider(), itineraryProvider: ItineraryProvider(), tripProvider: tripProvider),
    );
    await _openRoutePlanner(tester);

    await tester.tap(find.text('종료 호텔'));
    await tester.pumpAndSettle();
    expect(find.text('hotel search: HotelSelectionRole.end'), findsOneWidget);
  });

  testWidgets('optimize stays disabled until both hotels and at least 2 places are selected', (tester) async {
    final hotelProvider = HotelProvider();
    final itineraryProvider = ItineraryProvider(repository: FakeItineraryRepository());
    final tripProvider = TripProvider()..startBuildingDay('t1', 1);

    await tester.pumpWidget(_wrap(hotelProvider: hotelProvider, itineraryProvider: itineraryProvider, tripProvider: tripProvider));
    await _openRoutePlanner(tester);

    expect(find.text('1일차 동선 플래너'), findsOneWidget);
    ElevatedButton button() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '동선 최적화'));
    expect(button().onPressed, isNull);

    itineraryProvider.togglePlaceSelection('p1');
    itineraryProvider.togglePlaceSelection('p2');
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'hotels not selected yet');

    hotelProvider.selectStartHotel(_hotelA);
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'end hotel not selected yet');

    hotelProvider.selectEndHotel(_hotelA);
    await tester.pump();
    expect(button().onPressed, isNotNull);
    expect(find.text('왕복 (Round Trip)'), findsOneWidget);
  });

  testWidgets('optimizing with two different hotels shows "호텔 → 호텔", the summary, and the map', (tester) async {
    final itineraryRepository = FakeItineraryRepository()..resultToReturn = _optimizedResult;
    final itineraryProvider = ItineraryProvider(repository: itineraryRepository)
      ..togglePlaceSelection('p1')
      ..togglePlaceSelection('p2');
    final hotelProvider = HotelProvider()
      ..selectStartHotel(_hotelA)
      ..selectEndHotel(_hotelB);
    final tripProvider = TripProvider()..startBuildingDay('t1', 1);

    await tester.pumpWidget(_wrap(hotelProvider: hotelProvider, itineraryProvider: itineraryProvider, tripProvider: tripProvider));
    await _openRoutePlanner(tester);

    expect(find.text('호텔 → 호텔'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, '동선 최적화'));
    await tester.pumpAndSettle();

    expect(itineraryRepository.lastCall, {
      'tripId': 't1',
      'dayNumber': 1,
      'startHotelId': 'h1',
      'endHotelId': 'h2',
      'placeIds': ['p1', 'p2'],
      'transportMode': 'car',
    });
    expect(find.text('marker:A호텔'), findsOneWidget);
    expect(find.text('marker:B호텔'), findsOneWidget);
    expect(find.text('marker:해운대해수욕장'), findsOneWidget);
    expect(find.text('저장 완료 — 여행으로 돌아가기'), findsOneWidget);
  });

  testWidgets('selecting 도보 switches the optimize call to walk transport mode', (tester) async {
    final itineraryRepository = FakeItineraryRepository()..resultToReturn = _optimizedResult;
    final itineraryProvider = ItineraryProvider(repository: itineraryRepository)
      ..togglePlaceSelection('p1')
      ..togglePlaceSelection('p2');
    final hotelProvider = HotelProvider()
      ..selectStartHotel(_hotelA)
      ..selectEndHotel(_hotelB);
    final tripProvider = TripProvider()..startBuildingDay('t1', 1);

    await tester.pumpWidget(_wrap(hotelProvider: hotelProvider, itineraryProvider: itineraryProvider, tripProvider: tripProvider));
    await _openRoutePlanner(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '도보'));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, '동선 최적화'));
    await tester.pumpAndSettle();

    expect(itineraryRepository.lastCall?['transportMode'], 'walk');
  });

  testWidgets('shows an error view with a retry option when optimization fails', (tester) async {
    final itineraryRepository = FakeItineraryRepository()
      ..errorToThrow = const ApiException(code: 'HOTEL_NOT_FOUND', message: 'not found');
    final itineraryProvider = ItineraryProvider(repository: itineraryRepository)
      ..togglePlaceSelection('p1')
      ..togglePlaceSelection('p2');
    final hotelProvider = HotelProvider()
      ..selectStartHotel(_hotelA)
      ..selectEndHotel(_hotelB);
    final tripProvider = TripProvider()..startBuildingDay('t1', 1);

    await tester.pumpWidget(_wrap(hotelProvider: hotelProvider, itineraryProvider: itineraryProvider, tripProvider: tripProvider));
    await _openRoutePlanner(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '동선 최적화'));
    await tester.pumpAndSettle();

    expect(find.text('선택한 호텔을 찾을 수 없습니다.'), findsOneWidget);
  });

  testWidgets('tapping "저장 완료" returns to the trip detail screen and reloads the trip', (tester) async {
    final itineraryRepository = FakeItineraryRepository()..resultToReturn = _optimizedResult;
    final itineraryProvider = ItineraryProvider(repository: itineraryRepository)
      ..togglePlaceSelection('p1')
      ..togglePlaceSelection('p2');
    final tripRepository = FakeTripRepository();
    final tripProvider = TripProvider(repository: tripRepository)..startBuildingDay('t1', 1);
    final hotelProvider = HotelProvider()
      ..selectStartHotel(_hotelA)
      ..selectEndHotel(_hotelB);

    await tester.pumpWidget(_wrap(hotelProvider: hotelProvider, itineraryProvider: itineraryProvider, tripProvider: tripProvider));
    await _openRoutePlanner(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '동선 최적화'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('저장 완료 — 여행으로 돌아가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장 완료 — 여행으로 돌아가기'));
    await tester.pumpAndSettle();

    expect(find.text('go to route planner'), findsOneWidget);
    expect(tripProvider.activeTripId, isNull);
    expect(tripRepository.loadCalls, ['t1']);
  });
}
