import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/place_model.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/screens/analysis_tab_screen.dart';

import 'fakes/fake_map_widget.dart';
import 'fakes/fake_video_player_widget.dart';
import 'helpers/phone_viewport.dart';

const VideoModel _video = VideoModel(
  videoId: 'v1',
  youtubeVideoId: 'v1',
  title: '아산 브이로그',
  isCached: false,
  places: [
    PlaceModel(
      placeId: 'p1',
      name: '시장 식당',
      timestampSec: 88,
      latitude: 36.78,
      longitude: 127.0,
      address: '충남 아산시',
      source: 'transcript',
      confidence: 0.9,
    ),
  ],
);

class FakeVideoRepository extends VideoRepository {
  String? lastUrl;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    lastUrl = youtubeUrl;
    return _video;
  }
}

Widget _wrap(VideoProvider videoProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: videoProvider),
      ChangeNotifierProvider(create: (_) => BookmarkProvider()),
    ],
    child: MaterialApp(
      home: AnalysisTabScreen(
        mapRepository: const FakeMapRepository(),
        videoPlayerRepository: FakeVideoPlayerRepository(),
      ),
    ),
  );
}

void main() {
  testWidgets('offers the URL field while nothing has been analyzed', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(VideoProvider(repository: FakeVideoRepository())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analysisTabUrlField')), findsOneWidget);
    expect(find.text('동선 분석'), findsNothing);
  });

  testWidgets('keeps the analysis this tab is holding, with no back button', (tester) async {
    // The point of the tab: a video analyzed anywhere (here or on 홈) stays
    // reachable instead of being a screen the user has to keep re-opening.
    usePhoneViewport(tester);
    final videoProvider = VideoProvider(repository: FakeVideoRepository());
    await videoProvider.analyze('https://youtu.be/v1');

    await tester.pumpWidget(_wrap(videoProvider));
    await tester.pumpAndSettle();

    expect(find.text('아산 브이로그'), findsOneWidget);
    expect(find.text('시장 식당'), findsOneWidget);
    expect(find.byKey(const Key('analysisTabUrlField')), findsNothing);
    // Nothing to go back to from a tab root.
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });

  testWidgets('새 영상 분석 clears the result and brings the URL field back', (tester) async {
    usePhoneViewport(tester);
    final videoProvider = VideoProvider(repository: FakeVideoRepository());
    await videoProvider.analyze('https://youtu.be/v1');

    await tester.pumpWidget(_wrap(videoProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('analyzeAnotherVideoButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analysisTabUrlField')), findsOneWidget);
    expect(find.text('아산 브이로그'), findsNothing);
  });

  testWidgets('analyzing here shows the result in place, without navigating', (tester) async {
    usePhoneViewport(tester);
    final repository = FakeVideoRepository();
    await tester.pumpWidget(_wrap(VideoProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('analysisTabUrlField')), 'https://youtu.be/v1');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(repository.lastUrl, 'https://youtu.be/v1');
    expect(find.text('아산 브이로그'), findsOneWidget);
  });
}
