import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/shared_route_model.dart';
import 'package:travel_youtube_app/models/similar_taste_recommendation_model.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/models/video_search_result_model.dart';
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

  @override
  Future<VideoModel> analyze(String youtubeUrl) async {
    lastUrl = youtubeUrl;
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

Widget _wrap({required FakeVideoRepository videoRepository, RecommendationWizardProvider? wizard}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => VideoProvider(repository: videoRepository)),
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
    expect(find.text('브이로그 URL을 붙여넣으세요'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();

    expect(find.text('URL을 먼저 입력해 주세요.'), findsOneWidget);
    expect(videoRepository.lastUrl, isNull);
  });

  testWidgets('analyzing a URL opens the analysis screen', (tester) async {
    usePhoneViewport(tester);
    final videoRepository = FakeVideoRepository();
    await tester.pumpWidget(_wrap(videoRepository: videoRepository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('urlField')), 'https://youtu.be/v1');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(videoRepository.lastUrl, 'https://youtu.be/v1');
    expect(find.text('route:${AppRoutes.videoAnalysis}'), findsOneWidget);
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
