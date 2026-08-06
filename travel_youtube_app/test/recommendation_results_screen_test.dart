import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/video_model.dart';
import 'package:travel_youtube_app/models/video_search_result_model.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';
import 'package:travel_youtube_app/screens/recommendation_results_screen.dart';

class FakeVideoRepository extends VideoRepository {
  VideoModel? videoToReturn;
  List<VideoSearchResultModel> recommendationsToReturn = [];

  @override
  Future<VideoModel> analyze(String youtubeUrl) async => videoToReturn!;

  @override
  Future<List<VideoSearchResultModel>> searchByHashtag(String hashtag) async => throw UnimplementedError();

  @override
  Future<List<VideoSearchResultModel>> getRecommendations({
    required List<String> regions,
    required List<String> themes,
    required String duration,
  }) async =>
      recommendationsToReturn;
}

Widget _wrap(VideoProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const RecommendationResultsScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('video analysis screen'))),
    ),
  );
}

void main() {
  testWidgets('shows an empty message when there are no recommendations', (tester) async {
    final provider = VideoProvider(repository: FakeVideoRepository());
    await provider.searchByRecommendation(regions: ['제주'], themes: ['자연'], duration: '1박2일');

    await tester.pumpWidget(_wrap(provider));

    expect(find.text('조건에 맞는 추천 영상이 없습니다.'), findsOneWidget);
  });

  testWidgets('lists recommended videos and navigates on tap', (tester) async {
    final repository = FakeVideoRepository()
      ..videoToReturn = const VideoModel(videoId: 'v1', title: 'Trip', isCached: false, places: [])
      ..recommendationsToReturn = [
        const VideoSearchResultModel(
          videoId: 'v1',
          youtubeUrl: 'https://youtu.be/v1',
          title: 'title',
          thumbnailUrl: null,
          channelName: null,
          publishedAt: null,
        ),
      ];
    final provider = VideoProvider(repository: repository);
    await provider.searchByRecommendation(regions: ['제주'], themes: ['자연'], duration: '1박2일');

    await tester.pumpWidget(_wrap(provider));
    expect(find.text('title'), findsOneWidget);

    await tester.tap(find.text('title'));
    await tester.pumpAndSettle();

    expect(find.text('video analysis screen'), findsOneWidget);
  });
}
