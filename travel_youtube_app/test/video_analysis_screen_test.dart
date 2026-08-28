import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/place_model.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/screens/video_analysis_screen.dart';

import 'fakes/fake_map_widget.dart';
import 'fakes/fake_video_player_widget.dart';

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
  name: '어딘가 골목길',
  timestampSec: null,
  latitude: null,
  longitude: null,
  address: null,
  source: 'title',
  confidence: 0.3,
);

class FakeVideoRepository extends VideoRepository {
  VideoModel? videoToReturn;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async => videoToReturn!;
}

Widget _wrap({
  required VideoProvider videoProvider,
  required FakeVideoPlayerRepository videoPlayerRepository,
  RouteFactory? onGenerateRoute,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: videoProvider),
      ChangeNotifierProvider(create: (_) => BookmarkProvider()),
    ],
    child: MaterialApp(
      home: VideoAnalysisScreen(
        mapRepository: const FakeMapRepository(),
        videoPlayerRepository: videoPlayerRepository,
      ),
      onGenerateRoute: onGenerateRoute,
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator before a video is loaded', (tester) async {
    final videoProvider = VideoProvider(repository: FakeVideoRepository());

    await tester.pumpWidget(
      _wrap(videoProvider: videoProvider, videoPlayerRepository: FakeVideoPlayerRepository()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('fake-player'), findsNothing);
  });

  testWidgets('shows the video title, the player, and place cards once loaded', (tester) async {
    final repository = FakeVideoRepository()
      ..videoToReturn = const VideoModel(
        videoId: 'v1',
        title: '부산 브이로그',
        isCached: false,
        places: [_geocodedPlace, _ungeocodedPlace],
      );
    final videoProvider = VideoProvider(repository: repository);
    await videoProvider.analyze('https://youtu.be/v1');

    await tester.pumpWidget(
      _wrap(videoProvider: videoProvider, videoPlayerRepository: FakeVideoPlayerRepository()),
    );

    expect(find.text('부산 브이로그'), findsOneWidget);
    expect(find.text('fake-player video=v1'), findsOneWidget);
    expect(find.text('해운대해수욕장'), findsOneWidget);
    expect(find.text('어딘가 골목길'), findsOneWidget);
  });

  testWidgets('shows an empty message when the video has no places', (tester) async {
    final repository = FakeVideoRepository()
      ..videoToReturn = const VideoModel(videoId: 'v1', title: '빈 영상', isCached: false, places: []);
    final videoProvider = VideoProvider(repository: repository);
    await videoProvider.analyze('https://youtu.be/v1');

    await tester.pumpWidget(
      _wrap(videoProvider: videoProvider, videoPlayerRepository: FakeVideoPlayerRepository()),
    );

    expect(find.text('추출된 장소가 없습니다.'), findsOneWidget);
  });

  testWidgets('tapping a timestamp chip seeks the player to that second', (tester) async {
    final repository = FakeVideoRepository()
      ..videoToReturn = const VideoModel(
        videoId: 'v1',
        title: '부산 브이로그',
        isCached: false,
        places: [_geocodedPlace],
      );
    final videoProvider = VideoProvider(repository: repository);
    await videoProvider.analyze('https://youtu.be/v1');
    final playerRepository = FakeVideoPlayerRepository();

    await tester.pumpWidget(
      _wrap(videoProvider: videoProvider, videoPlayerRepository: playerRepository),
    );

    await tester.tap(find.textContaining('02:05'));
    await tester.pump();

    expect(playerRepository.seekCalls, [125]);
  });

  testWidgets('tapping the map button on a geocoded place shows the map with a marker', (tester) async {
    final repository = FakeVideoRepository()
      ..videoToReturn = const VideoModel(
        videoId: 'v1',
        title: '부산 브이로그',
        isCached: false,
        places: [_geocodedPlace],
      );
    final videoProvider = VideoProvider(repository: repository);
    await videoProvider.analyze('https://youtu.be/v1');

    await tester.pumpWidget(
      _wrap(videoProvider: videoProvider, videoPlayerRepository: FakeVideoPlayerRepository()),
    );

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();

    expect(find.text('marker:해운대해수욕장'), findsOneWidget);
  });

  testWidgets('the map button is disabled for a place with no coordinates', (tester) async {
    final repository = FakeVideoRepository()
      ..videoToReturn = const VideoModel(
        videoId: 'v1',
        title: '부산 브이로그',
        isCached: false,
        places: [_ungeocodedPlace],
      );
    final videoProvider = VideoProvider(repository: repository);
    await videoProvider.analyze('https://youtu.be/v1');

    await tester.pumpWidget(
      _wrap(videoProvider: videoProvider, videoPlayerRepository: FakeVideoPlayerRepository()),
    );

    final mapButton = tester.widget<IconButton>(find.byIcon(Icons.map_outlined));
    expect(mapButton.onPressed, isNull);
  });

  testWidgets('tapping a place card navigates to place detail, and popping with a timestamp seeks the player', (tester) async {
    final repository = FakeVideoRepository()
      ..videoToReturn = const VideoModel(
        videoId: 'v1',
        title: '부산 브이로그',
        isCached: false,
        places: [_geocodedPlace],
      );
    final videoProvider = VideoProvider(repository: repository);
    await videoProvider.analyze('https://youtu.be/v1');
    final playerRepository = FakeVideoPlayerRepository();

    await tester.pumpWidget(
      _wrap(
        videoProvider: videoProvider,
        videoPlayerRepository: playerRepository,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.pop(context, 125),
            child: const Text('place detail stub'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('해운대해수욕장'));
    await tester.pumpAndSettle();
    expect(find.text('place detail stub'), findsOneWidget);

    await tester.tap(find.text('place detail stub'));
    await tester.pumpAndSettle();

    expect(playerRepository.seekCalls, [125]);
  });
}
