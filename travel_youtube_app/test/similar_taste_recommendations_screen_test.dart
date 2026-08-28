import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/similar_taste_recommendation_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/similar_taste_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/repositories/similar_taste_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/similar_taste_recommendations_screen.dart';

const SimilarTasteRecommendationModel _rec = SimilarTasteRecommendationModel(
  placeId: 'p1',
  name: '흑돼지집',
  latitude: 33.51,
  longitude: 126.51,
  category: 'restaurant',
  score: 1.6,
  contributorCount: 2,
  reason: '취향이 비슷한 사용자 2명이 북마크한 곳이에요.',
);

class FakeSimilarTasteRepository extends SimilarTasteRepository {
  SimilarTasteResultModel? resultToReturn;
  ApiException? error;

  @override
  Future<SimilarTasteResultModel> getRecommendations({int? limit}) async {
    if (error != null) throw error!;
    return resultToReturn!;
  }
}

class FakeBookmarkRepository extends BookmarkRepository {
  @override
  Future<List<BookmarkModel>> listBookmarks() async => [];

  @override
  Future<String> addBookmark(String placeId) async => 'new-bookmark-id';

  @override
  Future<void> removeBookmark(String bookmarkId) async {}
}

Widget _wrap(SimilarTasteProvider provider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider(create: (_) => BookmarkProvider(repository: FakeBookmarkRepository())),
    ],
    child: MaterialApp(
      home: const SimilarTasteRecommendationsScreen(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    ),
  );
}

void main() {
  testWidgets('prompts to set taste preferences when the requester has none set', (tester) async {
    final repository = FakeSimilarTasteRepository()
      ..resultToReturn = const SimilarTasteResultModel(hasPreference: false, recommendations: []);
    await tester.pumpWidget(_wrap(SimilarTasteProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.textContaining('취향 설정을 하면'), findsOneWidget);
    expect(find.text('취향 설정하러 가기'), findsOneWidget);
  });

  testWidgets('shows an empty state when the requester has a preference but no similar users yet', (tester) async {
    final repository = FakeSimilarTasteRepository()
      ..resultToReturn = const SimilarTasteResultModel(hasPreference: true, recommendations: []);
    await tester.pumpWidget(_wrap(SimilarTasteProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('아직 비슷한 취향의 사용자가 없어요.'), findsOneWidget);
  });

  testWidgets('lists recommendations with their reason', (tester) async {
    final repository = FakeSimilarTasteRepository()
      ..resultToReturn = const SimilarTasteResultModel(hasPreference: true, recommendations: [_rec]);
    await tester.pumpWidget(_wrap(SimilarTasteProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('흑돼지집'), findsOneWidget);
    expect(find.text('취향이 비슷한 사용자 2명이 북마크한 곳이에요.'), findsOneWidget);
  });

  testWidgets('shows an error view with a retry option when loading fails', (tester) async {
    final repository = FakeSimilarTasteRepository()..error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');
    await tester.pumpWidget(_wrap(SimilarTasteProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
  });
}
