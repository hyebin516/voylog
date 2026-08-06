import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/models/video_search_result_model.dart';
import 'package:travel_youtube_app/providers/recommendation_wizard_provider.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/screens/recommendation_duration_screen.dart';

class FakeVideoRepository extends VideoRepository {
  List<VideoSearchResultModel> resultsToReturn = [];
  ApiException? error;
  List<String>? lastRegions;
  List<String>? lastThemes;
  String? lastDuration;

  @override
  Future<VideoModel> analyze(String youtubeUrl) async => throw UnimplementedError();

  @override
  Future<List<VideoSearchResultModel>> searchByHashtag(String hashtag) async => throw UnimplementedError();

  @override
  Future<List<VideoSearchResultModel>> getRecommendations({
    required List<String> regions,
    required List<String> themes,
    required String duration,
  }) async {
    lastRegions = regions;
    lastThemes = themes;
    lastDuration = duration;
    if (error != null) throw error!;
    return resultsToReturn;
  }
}

Widget _wrap(RecommendationWizardProvider wizardProvider, VideoProvider videoProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: wizardProvider),
      ChangeNotifierProvider.value(value: videoProvider),
    ],
    child: MaterialApp(
      home: const RecommendationDurationScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('results screen'))),
    ),
  );
}

void main() {
  testWidgets('search button is disabled until a duration is selected', (tester) async {
    final wizardProvider = RecommendationWizardProvider()
      ..toggleRegion('제주')
      ..toggleTheme('자연');
    await tester.pumpWidget(_wrap(wizardProvider, VideoProvider(repository: FakeVideoRepository())));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a duration and searching calls the repository and navigates to results', (tester) async {
    final wizardProvider = RecommendationWizardProvider()
      ..toggleRegion('제주')
      ..toggleTheme('자연');
    final repository = FakeVideoRepository()
      ..resultsToReturn = [
        const VideoSearchResultModel(
          videoId: 'v1',
          youtubeUrl: 'https://youtu.be/v1',
          title: 'title',
          thumbnailUrl: null,
          channelName: null,
          publishedAt: null,
        ),
      ];
    await tester.pumpWidget(_wrap(wizardProvider, VideoProvider(repository: repository)));

    await tester.tap(find.byKey(const Key('duration_1박2일')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('durationSearchButton')));
    await tester.pumpAndSettle();

    expect(repository.lastRegions, ['제주']);
    expect(repository.lastThemes, ['자연']);
    expect(repository.lastDuration, '1박2일');
    expect(find.text('results screen'), findsOneWidget);
  });
}
