import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/shared_route_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/screens/shared_route_detail_screen.dart';

import 'fakes/fake_map_widget.dart';

class FakeBookmarkRepository extends BookmarkRepository {
  @override
  Future<List<BookmarkModel>> listBookmarks() async => [];
}

final SharedRouteModel _route = SharedRouteModel.fromJson({
  'sharedRouteId': 'sr1',
  'title': '서면 보드게임 투어',
  'authorNickname': '여행자',
  'transportMode': 'walk',
  'placeCount': 3,
  'totalDistanceM': 900,
  'totalDurationSec': 720,
  'likeCount': 4,
  'likedByMe': false,
  'isOwner': false,
  'matchPercent': 72,
  'createdAt': '2026-09-15T10:00:00Z',
  'routeData': [
    {
      'order': 0,
      'type': 'place',
      'placeId': 'kakao:1',
      'name': '레드버튼 서면2호점',
      'latitude': 35.157,
      'longitude': 129.059,
      'legDistanceM': null,
      'legDurationSec': null,
    },
    {
      'order': 1,
      'type': 'place',
      'placeId': 'kakao:2',
      'name': '홈즈앤루팡 서면점',
      'latitude': 35.158,
      'longitude': 129.060,
      'legDistanceM': 400,
      'legDurationSec': 320,
    },
    // Published before coordinates were kept and never backfilled: it is
    // listed, but can't be put on the map.
    {'order': 2, 'type': 'place', 'placeId': 'kakao:3', 'name': '데블다이스 서면중앙점', 'legDistanceM': 500, 'legDurationSec': 400},
  ],
});

Widget _wrap() {
  return ChangeNotifierProvider(
    create: (_) => BookmarkProvider(repository: FakeBookmarkRepository()),
    child: MaterialApp(
      home: SharedRouteDetailScreen(route: _route, mapRepository: const FakeMapRepository()),
    ),
  );
}

void main() {
  testWidgets('shows the title, author, match and every stop in order', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('서면 보드게임 투어'), findsOneWidget);
    expect(find.textContaining('여행자 · 장소 3곳 · 좋아요 4'), findsOneWidget);
    expect(find.text('취향 일치 72%'), findsOneWidget);
    expect(find.text('레드버튼 서면2호점'), findsWidgets);
    expect(find.text('데블다이스 서면중앙점'), findsWidgets);
    // A shared route has no hotels, so no 왕복 / 호텔 → 호텔 chip.
    expect(find.text('왕복'), findsNothing);
    expect(find.text('호텔 → 호텔'), findsNothing);
  });

  testWidgets('maps only the stops that have coordinates', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('marker:레드버튼 서면2호점'), findsOneWidget);
    expect(find.text('marker:홈즈앤루팡 서면점'), findsOneWidget);
    expect(find.text('marker:데블다이스 서면중앙점'), findsNothing);
  });

  test('parses routeData from the feed and defaults it to empty', () {
    expect(_route.routeData.map((p) => p.name), ['레드버튼 서면2호점', '홈즈앤루팡 서면점', '데블다이스 서면중앙점']);
    expect(_route.routeData[2].latitude, isNull);

    final withoutStops = SharedRouteModel.fromJson({
      'sharedRouteId': 'sr2',
      'title': 't',
      'authorNickname': null,
      'transportMode': 'car',
      'placeCount': 0,
      'totalDistanceM': null,
      'totalDurationSec': null,
      'likeCount': 0,
      'likedByMe': false,
      'matchPercent': null,
      'createdAt': '2026-09-15T10:00:00Z',
    });
    expect(withoutStops.routeData, isEmpty);
  });
}
