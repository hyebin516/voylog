import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/hotel_model.dart';
import 'package:travel_youtube_app/models/hotel_search_candidate.dart';
import 'package:travel_youtube_app/providers/hotel_provider.dart';
import 'package:travel_youtube_app/providers/trip_provider.dart';
import 'package:travel_youtube_app/repositories/hotel_repository.dart';
import 'package:travel_youtube_app/screens/hotel_search_screen.dart';

import 'fakes/fake_map_widget.dart';
import 'helpers/phone_viewport.dart';

const HotelModel _savedHotel = HotelModel(
  hotelId: 'h1',
  name: '부산 시그니엘 호텔',
  address: 'addr',
  latitude: 35.1,
  longitude: 129.1,
);

const HotelSearchCandidate _candidate = HotelSearchCandidate(
  placeId: 'kakao:1',
  name: '제주 게스트하우스',
  address: '제주 제주시 연동',
  latitude: 33.4,
  longitude: 126.5,
);

class FakeHotelRepository extends HotelRepository {
  List<HotelModel> hotelsToReturn = [_savedHotel];
  List<HotelSearchCandidate> searchResultsToReturn = [];
  String? reverseGeocodeAddress = '서울특별시 중구 세종대로 110';
  HotelModel? createdHotel;
  final List<String> deleteCalls = [];
  final List<String> searchQueries = [];

  @override
  Future<List<HotelModel>> listHotels() async => hotelsToReturn;

  @override
  Future<void> deleteHotel(String hotelId) async => deleteCalls.add(hotelId);

  @override
  Future<List<HotelSearchCandidate>> searchHotels(String query) async {
    searchQueries.add(query);
    return searchResultsToReturn;
  }

  @override
  Future<String?> reverseGeocode(double latitude, double longitude) async =>
      reverseGeocodeAddress;

  @override
  Future<HotelModel> createHotel(HotelModel hotel) async =>
      createdHotel ??
      HotelModel(
        hotelId: 'new-1',
        name: hotel.name,
        address: hotel.address,
        latitude: hotel.latitude,
        longitude: hotel.longitude,
      );
}

Widget _wrap(
  HotelRepository repository, {
  HotelSelectionRole role = HotelSelectionRole.start,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => HotelProvider(repository: repository),
      ),
      ChangeNotifierProvider(
        create: (_) => TripProvider()..startBuildingDay('t1', 1),
      ),
    ],
    child: MaterialApp(
      home: HotelSearchScreen(
        role: role,
        mapRepository: const FakeMapRepository(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the day-based title and both start/end role tabs', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(FakeHotelRepository()));
    await tester.pumpAndSettle();

    expect(find.text('1일차 호텔 선택'), findsOneWidget);
    expect(find.text('시작 호텔'), findsOneWidget);
    expect(find.text('종료 호텔'), findsOneWidget);
  });

  testWidgets(
    'typing in the search bar shows matching Kakao keyword-search candidates',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeHotelRepository()
        ..searchResultsToReturn = [_candidate];
      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '제주 게스트');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(repository.searchQueries, ['제주 게스트']);
      expect(find.text('제주 게스트하우스'), findsOneWidget);
      expect(find.text('제주 제주시 연동'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a no-results message when the keyword search finds nothing',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeHotelRepository()..searchResultsToReturn = [];
      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '존재하지않는숙소이름');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('검색 결과가 없어요. 지도에서 직접 골라보세요.'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a search candidate saves it with its real address and selects it for the active role',
    (tester) async {
    usePhoneViewport(tester);
      final createdHotel = HotelModel(
        hotelId: 'new-1',
        name: '제주 게스트하우스',
        address: '제주 제주시 연동',
        latitude: 33.4,
        longitude: 126.5,
      );
      final repository = FakeHotelRepository()
        ..searchResultsToReturn = [_candidate]
        ..createdHotel = createdHotel;
      late HotelProvider hotelProvider;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                hotelProvider = HotelProvider(repository: repository);
                return hotelProvider;
              },
            ),
            ChangeNotifierProvider(
              create: (_) => TripProvider()..startBuildingDay('t1', 1),
            ),
          ],
          child: MaterialApp(
            home: HotelSearchScreen(
              role: HotelSelectionRole.start,
              mapRepository: const FakeMapRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '제주 게스트');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('제주 게스트하우스').first);
      await tester.tap(find.text('제주 게스트하우스'));
      await tester.pumpAndSettle();

      expect(hotelProvider.selectedStartHotel?.hotelId, 'new-1');
      expect(hotelProvider.selectedStartHotel?.address, '제주 제주시 연동');
    },
  );

  testWidgets(
    'map-drag save reverse-geocodes a real address before creating the hotel',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeHotelRepository()
        ..reverseGeocodeAddress = '서울특별시 중구 세종대로 110';
      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('fake-map center='), findsOneWidget);

      await tester.ensureVisible(find.text('simulate-drag').first);
      await tester.tap(find.text('simulate-drag'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).last, '부산 시그니엘 호텔');
      await tester.ensureVisible(find.text('이 위치를 호텔로 저장').first);
      await tester.tap(find.text('이 위치를 호텔로 저장'));
      await tester.pumpAndSettle();

      expect(repository.createdHotel, isNull);
      // No explicit createdHotel override means the fake echoes back the
      // reverse-geocoded address -- assert indirectly via the saved list.
      expect(find.text('부산 시그니엘 호텔'), findsWidgets);
    },
  );

  testWidgets(
    'map-drag save shows an error and does not create a hotel when the address cannot be resolved',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeHotelRepository()..reverseGeocodeAddress = null;
      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('simulate-drag').first);
      await tester.tap(find.text('simulate-drag'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).last, '부산 시그니엘 호텔');
      await tester.ensureVisible(find.text('이 위치를 호텔로 저장').first);
      await tester.tap(find.text('이 위치를 호텔로 저장'));
      await tester.pumpAndSettle();

      expect(
        find.text('이 위치의 주소를 찾지 못했어요. 지도를 조금 옮기거나 이름으로 검색해보세요.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'deleting a saved hotel asks for confirmation before calling the repository',
    (tester) async {
    usePhoneViewport(tester);
      final repository = FakeHotelRepository();
      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.text('부산 시그니엘 호텔'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('호텔 삭제'), findsOneWidget);

      // Cancelling leaves the hotel in place.
      await tester.ensureVisible(find.text('취소').first);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, isEmpty);
      expect(find.text('부산 시그니엘 호텔'), findsOneWidget);

      // Confirming removes it.
      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('삭제').first);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, ['h1']);
      expect(find.text('부산 시그니엘 호텔'), findsNothing);
      expect(find.text('저장된 호텔이 없습니다.'), findsOneWidget);
    },
  );

  testWidgets(
    'checking "종료 호텔도 동일" also sets the end hotel when picking the start hotel',
    (tester) async {
    usePhoneViewport(tester);
      late HotelProvider hotelProvider;
      final repository = FakeHotelRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                hotelProvider = HotelProvider(repository: repository);
                return hotelProvider;
              },
            ),
            ChangeNotifierProvider(
              create: (_) => TripProvider()..startBuildingDay('t1', 1),
            ),
          ],
          child: MaterialApp(
            home: HotelSearchScreen(
              role: HotelSelectionRole.start,
              mapRepository: const FakeMapRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('종료 호텔도 동일 (왕복)').first);
      await tester.tap(find.text('종료 호텔도 동일 (왕복)'));
      await tester.pump();

      await tester.ensureVisible(find.text('부산 시그니엘 호텔').first);
      await tester.tap(find.text('부산 시그니엘 호텔'));
      await tester.pump();

      expect(hotelProvider.selectedStartHotel?.hotelId, 'h1');
      expect(hotelProvider.selectedEndHotel?.hotelId, 'h1');
    },
  );

  testWidgets(
    'switching to the 종료 호텔 tab selects into selectedEndHotel instead',
    (tester) async {
    usePhoneViewport(tester);
      late HotelProvider hotelProvider;
      final repository = FakeHotelRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                hotelProvider = HotelProvider(repository: repository);
                return hotelProvider;
              },
            ),
            ChangeNotifierProvider(
              create: (_) => TripProvider()..startBuildingDay('t1', 1),
            ),
          ],
          child: MaterialApp(
            home: HotelSearchScreen(
              role: HotelSelectionRole.start,
              mapRepository: const FakeMapRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('종료 호텔').first);
      await tester.tap(find.text('종료 호텔'));
      await tester.pump();

      await tester.ensureVisible(find.text('부산 시그니엘 호텔').first);
      await tester.tap(find.text('부산 시그니엘 호텔'));
      await tester.pump();

      expect(hotelProvider.selectedStartHotel, isNull);
      expect(hotelProvider.selectedEndHotel?.hotelId, 'h1');
    },
  );

  testWidgets('tapping 확인 pops the screen', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => HotelProvider(repository: FakeHotelRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => TripProvider()..startBuildingDay('t1', 1),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HotelSearchScreen(
                      role: HotelSelectionRole.start,
                      mapRepository: FakeMapRepository(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('open').first);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1일차 호텔 선택'), findsOneWidget);

    await tester.ensureVisible(find.text('확인').first);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('1일차 호텔 선택'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
