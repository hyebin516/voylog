import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/shared_route_model.dart';
import 'package:travel_youtube_app/models/similar_taste_recommendation_model.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/models/video_search_result_model.dart';
import 'package:travel_youtube_app/providers/app_shell_provider.dart';
import 'package:travel_youtube_app/providers/recommendation_wizard_provider.dart';
import 'package:travel_youtube_app/providers/shared_route_provider.dart';
import 'package:travel_youtube_app/providers/similar_taste_provider.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/shared_route_repository.dart';
import 'package:travel_youtube_app/repositories/similar_taste_repository.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/home_screen.dart';

import 'helpers/phone_viewport.dart';

class FakeVideoRepository extends VideoRepository {
  String? lastUrl;
  String? lastHashtag;

  /// Number of leading calls that fail, so a retry can be made to succeed.
  int failuresBeforeSuccess = 0;
  int analyzeCalls = 0;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    lastUrl = youtubeUrl;
    analyzeCalls++;
    if (analyzeCalls <= failuresBeforeSuccess) {
      throw const ApiException(code: 'AI_TIMEOUT', message: 'timed out');
    }
    return const VideoModel(videoId: 'v1', youtubeVideoId: 'v1', title: 't', isCached: false, places: []);
  }

  @override
  Future<List<VideoSearchResultModel>> searchByHashtag(String hashtag) async {
    lastHashtag = hashtag;
    return [];
  }
}

// HomeScreen loads the similar-taste and shared-route feeds on open; these
// keep that off the network.
class FakeSimilarTasteRepository extends SimilarTasteRepository {
  @override
  Future<SimilarTasteResultModel> getRecommendations({int? limit}) async =>
      const SimilarTasteResultModel(hasPreference: false, recommendations: []);
}

class FakeSharedRouteRepository extends SharedRouteRepository {
  @override
  Future<List<SharedRouteModel>> getFeed({int? limit}) async => [];
}

Widget _wrap({
  required FakeVideoRepository videoRepository,
  RecommendationWizardProvider? wizard,
  AppShellProvider? shell,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => VideoProvider(repository: videoRepository)),
      ChangeNotifierProvider.value(value: shell ?? AppShellProvider()),
      ChangeNotifierProvider.value(value: wizard ?? RecommendationWizardProvider()),
      ChangeNotifierProvider(create: (_) => SimilarTasteProvider(repository: FakeSimilarTasteRepository())),
      ChangeNotifierProvider(create: (_) => SharedRouteProvider(repository: FakeSharedRouteRepository())),
    ],
    child: MaterialApp(
      home: const HomeScreen(),
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => Scaffold(body: Text('route:${settings.name}')), settings: settings),
    ),
  );
}

void main() {
  testWidgets('shows the URL input and warns when analyzing an empty URL', (tester) async {
    usePhoneViewport(tester);
    final videoRepository = FakeVideoRepository();
    await tester.pumpWidget(_wrap(videoRepository: videoRepository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('urlField')), findsOneWidget);
    expect(find.text('YouTube 링크 붙여넣기'), findsOneWidget);

    await tester.tap(find.byKey(const Key('analyzeButton')));
    await tester.pump();

    expect(find.text('URL을 먼저 입력해 주세요.'), findsOneWidget);
    expect(videoRepository.lastUrl, isNull);
  });

  testWidgets('analyzing a URL hands the result to the 분석 tab and frees 홈', (tester) async {
    usePhoneViewport(tester);
    final videoRepository = FakeVideoRepository();
    final shell = AppShellProvider();
    await tester.pumpWidget(_wrap(videoRepository: videoRepository, shell: shell));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('urlField')), 'https://youtu.be/v1');
    await tester.tap(find.byKey(const Key('analyzeButton')));
    await tester.pumpAndSettle();

    expect(videoRepository.lastUrl, 'https://youtu.be/v1');
    // The result is not stacked on top of 홈 any more -- it lives on the
    // 분석 tab, and 홈's field is empty for the next video.
    expect(shell.tabIndex, AppShellProvider.analysisTab);
    expect(find.text('route:${AppRoutes.videoAnalysis}'), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('urlField'))).controller!.text, isEmpty);
  });

  testWidgets('a success reached by 다시 시도 is handed off like any other', (tester) async {
    // The hand-off used to hang off the analyze() call this screen awaited.
    // That call had already finished -- failing -- by the time 다시 시도 ran
    // its own, so a retried success left the user on 홈 with the URL still in
    // the box and no hint that the analysis had worked.
    usePhoneViewport(tester);
    final videoRepository = FakeVideoRepository()..failuresBeforeSuccess = 1;
    final shell = AppShellProvider();
    await tester.pumpWidget(_wrap(videoRepository: videoRepository, shell: shell));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('urlField')), 'https://youtu.be/v1');
    await tester.tap(find.byKey(const Key('analyzeButton')));
    await tester.pumpAndSettle();

    expect(find.text('분석하지 못했어요'), findsOneWidget);
    expect(shell.tabIndex, isNot(AppShellProvider.analysisTab));

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(videoRepository.analyzeCalls, 2);
    expect(shell.tabIndex, AppShellProvider.analysisTab);
    expect(tester.widget<TextField>(find.byKey(const Key('urlField'))).controller!.text, isEmpty);
  });

  testWidgets('cancelling a failed analysis leaves 홈 as it was', (tester) async {
    usePhoneViewport(tester);
    final videoRepository = FakeVideoRepository()..failuresBeforeSuccess = 99;
    final shell = AppShellProvider();
    await tester.pumpWidget(_wrap(videoRepository: videoRepository, shell: shell));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('urlField')), 'https://youtu.be/v1');
    await tester.tap(find.byKey(const Key('analyzeButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(shell.tabIndex, isNot(AppShellProvider.analysisTab));
    // The URL stays put, so the user can fix a typo instead of retyping it.
    expect(
      tester.widget<TextField>(find.byKey(const Key('urlField'))).controller!.text,
      'https://youtu.be/v1',
    );
  });

  testWidgets('tapping a hashtag chip searches for it and opens the results', (tester) async {
    usePhoneViewport(tester);
    final videoRepository = FakeVideoRepository();
    await tester.pumpWidget(_wrap(videoRepository: videoRepository));
    await tester.pumpAndSettle();

    expect(find.text('해시태그로 브이로그 찾아보기'), findsOneWidget);

    await tester.ensureVisible(find.text('#부산여행'));
    await tester.tap(find.text('#부산여행'));
    await tester.pumpAndSettle();

    expect(videoRepository.lastHashtag, '부산여행');
    expect(find.text('route:${AppRoutes.recommendationResults}'), findsOneWidget);
  });

    testWidgets('the 내 여행 shortcut steps aside while the keyboard is open', (tester) async {
    // The Scaffold lifts its FAB above the keyboard, which parked it right
    // on top of whatever sits at the bottom of the sheet.
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap(videoRepository: FakeVideoRepository()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('내 여행'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.byTooltip('내 여행'), findsNothing);
  });

    testWidgets('더보기 resets the recommendation wizard and opens its first step', (tester) async {
    usePhoneViewport(tester);
    final wizard = RecommendationWizardProvider()..toggleRegion('제주');
    await tester.pumpWidget(_wrap(videoRepository: FakeVideoRepository(), wizard: wizard));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('더보기'));
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(wizard.selectedRegions, isEmpty);
    expect(find.text('route:${AppRoutes.recommendationRegion}'), findsOneWidget);
  });
}
