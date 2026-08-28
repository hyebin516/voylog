import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/providers/itinerary_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/bookmark_screen.dart';

BookmarkModel _bookmark(String placeId, String name) {
  return BookmarkModel(
    bookmarkId: 'b-$placeId',
    placeId: placeId,
    videoId: 'v1',
    name: name,
    address: '부산 해운대구',
    latitude: 35.15,
    longitude: 129.16,
    timestampSec: 90,
    source: 'transcript',
    confidence: 0.8,
    bookmarkedAt: DateTime(2026, 1, 1),
  );
}

class FakeBookmarkRepository extends BookmarkRepository {
  List<BookmarkModel> bookmarksToReturn = [];
  ApiException? errorToThrow;
  int loadCallCount = 0;

  @override
  Future<List<BookmarkModel>> listBookmarks() async {
    loadCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return bookmarksToReturn;
  }
}

Widget _wrap({required BookmarkProvider bookmarkProvider, required ItineraryProvider itineraryProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: bookmarkProvider),
      ChangeNotifierProvider.value(value: itineraryProvider),
    ],
    child: MaterialApp(
      home: const BookmarkScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.routePlanner) {
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Text('route planner screen')), settings: settings);
        }
        return null;
      },
    ),
  );
}

void main() {
  testWidgets('loads and shows bookmarked places on open', (tester) async {
    final repository = FakeBookmarkRepository()
      ..bookmarksToReturn = [_bookmark('p1', '해운대해수욕장'), _bookmark('p2', '광안리해수욕장')];
    final bookmarkProvider = BookmarkProvider(repository: repository);

    await tester.pumpWidget(_wrap(bookmarkProvider: bookmarkProvider, itineraryProvider: ItineraryProvider()));
    await tester.pumpAndSettle();

    expect(repository.loadCallCount, 1);
    expect(find.text('해운대해수욕장'), findsOneWidget);
    expect(find.text('광안리해수욕장'), findsOneWidget);
  });

  testWidgets('shows an empty message when there are no bookmarks', (tester) async {
    final bookmarkProvider = BookmarkProvider(repository: FakeBookmarkRepository());

    await tester.pumpWidget(_wrap(bookmarkProvider: bookmarkProvider, itineraryProvider: ItineraryProvider()));
    await tester.pumpAndSettle();

    expect(find.text('북마크한 장소가 없습니다.'), findsOneWidget);
  });

  testWidgets('shows an error view with a retry option when loading fails', (tester) async {
    final repository = FakeBookmarkRepository()
      ..errorToThrow = const ApiException(code: 'NETWORK_ERROR', message: 'boom');
    final bookmarkProvider = BookmarkProvider(repository: repository);

    await tester.pumpWidget(_wrap(bookmarkProvider: bookmarkProvider, itineraryProvider: ItineraryProvider()));
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);

    repository.errorToThrow = null;
    repository.bookmarksToReturn = [_bookmark('p1', '해운대해수욕장')];
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('해운대해수욕장'), findsOneWidget);
  });

  testWidgets('selecting places updates the counter and enables "동선 만들기" at 2 places', (tester) async {
    final repository = FakeBookmarkRepository()
      ..bookmarksToReturn = [_bookmark('p1', '해운대해수욕장'), _bookmark('p2', '광안리해수욕장')];
    final bookmarkProvider = BookmarkProvider(repository: repository);
    final itineraryProvider = ItineraryProvider();

    await tester.pumpWidget(_wrap(bookmarkProvider: bookmarkProvider, itineraryProvider: itineraryProvider));
    await tester.pumpAndSettle();

    expect(find.text('동선에 포함할 장소를 2~10개 선택하세요 (0개 선택됨)'), findsOneWidget);
    ElevatedButton button() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '동선 만들기'));
    expect(button().onPressed, isNull);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('동선에 포함할 장소를 2~10개 선택하세요 (1개 선택됨)'), findsOneWidget);
    expect(button().onPressed, isNull);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    expect(find.text('동선에 포함할 장소를 2~10개 선택하세요 (2개 선택됨)'), findsOneWidget);
    expect(button().onPressed, isNotNull);
  });

  testWidgets('tapping "동선 만들기" navigates to the route planner', (tester) async {
    final repository = FakeBookmarkRepository()
      ..bookmarksToReturn = [_bookmark('p1', '해운대해수욕장'), _bookmark('p2', '광안리해수욕장')];
    final bookmarkProvider = BookmarkProvider(repository: repository);
    final itineraryProvider = ItineraryProvider()
      ..togglePlaceSelection('p1')
      ..togglePlaceSelection('p2');

    await tester.pumpWidget(_wrap(bookmarkProvider: bookmarkProvider, itineraryProvider: itineraryProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, '동선 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('route planner screen'), findsOneWidget);
  });
}
