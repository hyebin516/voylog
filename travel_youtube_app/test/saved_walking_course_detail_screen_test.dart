import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/providers/saved_walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/screens/saved_walking_course_detail_screen.dart';

import 'fakes/fake_map_widget.dart';

final SavedWalkingCourseModel _course = SavedWalkingCourseModel(
  savedCourseId: 'sc1',
  region: '제주',
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 2119,
  totalDurationSec: 1897,
  routeData: [
    RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주 중심', latitude: 33.5, longitude: 126.5),
    RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '흑돼지집', latitude: 33.51, longitude: 126.51),
  ],
  createdAt: DateTime(2026, 8, 28),
);

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  ApiException? deleteError;
  final List<String> deleteCalls = [];

  @override
  Future<void> delete(String savedCourseId) async {
    deleteCalls.add(savedCourseId);
    if (deleteError != null) throw deleteError!;
  }
}

Widget _wrap(SavedWalkingCourseProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: SavedWalkingCourseDetailScreen(course: _course, mapRepository: const FakeMapRepository()),
    ),
  );
}

void main() {
  testWidgets('shows the course summary and a map marker for each place', (tester) async {
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: FakeSavedWalkingCourseRepository())));
    await tester.pumpAndSettle();

    expect(find.text('제주 코스'), findsOneWidget);
    expect(find.text('왕복'), findsOneWidget);
    expect(find.text('marker:흑돼지집'), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation, then pops on success', (tester) async {
    final repository = FakeSavedWalkingCourseRepository();
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('코스 삭제'), findsOneWidget);

    // Cancelling does not delete.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, isEmpty);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, ['sc1']);
  });
}
