import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/hotel_model.dart';
import 'package:travel_youtube_app/providers/hotel_provider.dart';
import 'package:travel_youtube_app/repositories/hotel_repository.dart';
import 'package:travel_youtube_app/screens/hotel_search_screen.dart';

import 'fakes/fake_map_widget.dart';

const HotelModel _savedHotel = HotelModel(hotelId: 'h1', name: '부산 시그니엘 호텔', address: 'addr', latitude: 35.1, longitude: 129.1);

class FakeHotelRepository extends HotelRepository {
  List<HotelModel> hotelsToReturn = [_savedHotel];
  final List<String> deleteCalls = [];

  @override
  Future<List<HotelModel>> listHotels() async => hotelsToReturn;

  @override
  Future<void> deleteHotel(String hotelId) async => deleteCalls.add(hotelId);
}

void main() {
  testWidgets('HotelSearchScreen enables save after picking a location and entering a name', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HotelProvider(),
        child: const MaterialApp(
          home: HotelSearchScreen(
            role: HotelSelectionRole.start,
            mapRepository: FakeMapRepository(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('시작 호텔 선택'), findsOneWidget);
    expect(find.textContaining('fake-map center='), findsOneWidget);

    // Simulate the user dragging the map to settle on a new center.
    await tester.tap(find.text('simulate-drag'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '부산 시그니엘 호텔');
    expect(find.text('이 위치를 호텔로 저장'), findsOneWidget);
  });

  testWidgets('deleting a saved hotel asks for confirmation before calling the repository', (tester) async {
    final repository = FakeHotelRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HotelProvider(repository: repository),
        child: const MaterialApp(
          home: HotelSearchScreen(
            role: HotelSelectionRole.start,
            mapRepository: FakeMapRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('부산 시그니엘 호텔'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('호텔 삭제'), findsOneWidget);

    // Cancelling leaves the hotel in place.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, isEmpty);
    expect(find.text('부산 시그니엘 호텔'), findsOneWidget);

    // Confirming removes it.
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, ['h1']);
    expect(find.text('부산 시그니엘 호텔'), findsNothing);
    expect(find.text('저장된 호텔이 없습니다.'), findsOneWidget);
  });
}
