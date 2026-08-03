import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/place_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/screens/place_detail_screen.dart';

import 'fakes/fake_map_widget.dart';

const PlaceModel _geocodedPlace = PlaceModel(
  placeId: 'p1',
  name: '해운대해수욕장',
  timestampSec: 125,
  latitude: 35.1587,
  longitude: 129.1603,
  address: '부산 해운대구',
  source: 'transcript',
  confidence: 0.9,
);

const PlaceModel _ungeocodedPlace = PlaceModel(
  placeId: 'p2',
  name: '어딘가',
  timestampSec: null,
  latitude: null,
  longitude: null,
  address: null,
  source: 'title',
  confidence: 0.3,
);

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => BookmarkProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows the place name, address, timestamp, and a map marker', (tester) async {
    await tester.pumpWidget(
      _wrap(const PlaceDetailScreen(place: _geocodedPlace, mapRepository: FakeMapRepository())),
    );

    expect(find.text('해운대해수욕장'), findsWidgets);
    expect(find.text('부산 해운대구'), findsOneWidget);
    expect(find.textContaining('02:05'), findsOneWidget);
    expect(find.text('marker:해운대해수욕장'), findsOneWidget);
    expect(find.text('영상에서 이 장면 보기'), findsOneWidget);
  });

  testWidgets('shows a placeholder instead of a map when the place has no coordinates', (tester) async {
    await tester.pumpWidget(
      _wrap(const PlaceDetailScreen(place: _ungeocodedPlace, mapRepository: FakeMapRepository())),
    );

    expect(find.text('위치 정보가 없습니다.'), findsOneWidget);
    expect(find.textContaining('fake-map'), findsNothing);
    expect(find.text('영상에서 이 장면 보기'), findsNothing); // no timestamp either
  });

  testWidgets('tapping "영상에서 이 장면 보기" pops with the timestamp', (tester) async {
    int? poppedResult;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BookmarkProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              child: const Text('open'),
              onPressed: () async {
                poppedResult = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlaceDetailScreen(place: _geocodedPlace, mapRepository: FakeMapRepository()),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('영상에서 이 장면 보기'));
    await tester.pumpAndSettle();

    expect(poppedResult, 125);
  });
}
