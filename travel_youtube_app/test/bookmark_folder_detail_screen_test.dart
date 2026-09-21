import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/screens/bookmark_folder_detail_screen.dart';

BookmarkModel _bookmark(String bookmarkId, String name) {
  return BookmarkModel(
    bookmarkId: bookmarkId,
    placeId: 'p-$bookmarkId',
    videoId: 'v1',
    name: name,
    address: 'addr',
    latitude: 35.0,
    longitude: 129.0,
    timestampSec: 10,
    source: 'transcript',
    confidence: 0.9,
    bookmarkedAt: DateTime(2026, 1, 1),
  );
}

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  List<BookmarkModel> bookmarksToReturn = [];
  final List<String> removeCalls = [];
  String? routedFolderId;

  @override
  Future<WalkingCourseModel> createRoute(String folderId) async {
    routedFolderId = folderId;
    return const WalkingCourseModel(
      course: WalkingCourseRouteModel(
        routeType: 'roundTrip',
        transportMode: 'walk',
        totalDistanceM: 1200,
        totalDurationSec: 900,
        routeData: [],
      ),
      recommendations: [],
    );
  }

  @override
  Future<List<BookmarkModel>> listBookmarksInFolder(String folderId) async =>
      bookmarksToReturn;

  @override
  Future<void> removeBookmarkFromFolder(
    String folderId,
    String bookmarkId,
  ) async {
    removeCalls.add(bookmarkId);
    bookmarksToReturn = bookmarksToReturn
        .where((b) => b.bookmarkId != bookmarkId)
        .toList();
  }

  @override
  Future<List<BookmarkFolderModel>> listFolders() async => [];
}

Widget _wrap(
  BookmarkFolderProvider provider, {
  WalkingCourseProvider? courseProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider.value(value: courseProvider ?? WalkingCourseProvider()),
    ],
    child: MaterialApp(
      home: const BookmarkFolderDetailScreen(folderId: 'f1'),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
      ),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when the folder has no bookmarks yet', (
    tester,
  ) async {
    final repository = FakeBookmarkFolderRepository();
    await tester.pumpWidget(
      _wrap(BookmarkFolderProvider(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 폴더에 담긴 북마크가 없습니다.'), findsOneWidget);
  });

  testWidgets('lists the bookmarks currently in the folder', (tester) async {
    final repository = FakeBookmarkFolderRepository()
      ..bookmarksToReturn = [_bookmark('b1', '해운대해수욕장')];
    await tester.pumpWidget(
      _wrap(BookmarkFolderProvider(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('해운대해수욕장'), findsOneWidget);
  });

  testWidgets('tapping the remove icon takes the bookmark out of the folder', (
    tester,
  ) async {
    final repository = FakeBookmarkFolderRepository()
      ..bookmarksToReturn = [_bookmark('b1', '해운대해수욕장')];
    await tester.pumpWidget(
      _wrap(BookmarkFolderProvider(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, ['b1']);
    expect(find.text('해운대해수욕장'), findsNothing);
  });

  testWidgets('tapping the add button navigates to the picker screen', (
    tester,
  ) async {
    final repository = FakeBookmarkFolderRepository();
    await tester.pumpWidget(
      _wrap(BookmarkFolderProvider(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('route:/bookmark-folder-picker'), findsOneWidget);
  });

  testWidgets(
    '"AI 동선 생성하기" is shown but disabled when the folder has fewer than 2 bookmarks',
    (tester) async {
      final repository = FakeBookmarkFolderRepository()
        ..bookmarksToReturn = [_bookmark('b1', '해운대해수욕장')];
      await tester.pumpWidget(
        _wrap(BookmarkFolderProvider(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI 동선 생성하기'), findsOneWidget);
      await tester.tap(find.text('AI 동선 생성하기'));
      await tester.pumpAndSettle();
      // Disabled -- tapping it does nothing (no navigation).
      expect(find.textContaining('route:'), findsNothing);
    },
  );

  testWidgets(
    'tapping "AI 동선 생성하기" routes the folder itself and opens the result',
    (tester) async {
      // It used to hand the user to the 여행 tab to pick a trip, a day and
      // two hotels -- so the button never actually produced a route.
      final repository = FakeBookmarkFolderRepository()
        ..bookmarksToReturn = [
          _bookmark('b1', '해운대해수욕장'),
          _bookmark('b2', '스타벅스'),
        ];
      final courseProvider = WalkingCourseProvider(folderRepository: repository);
      await tester.pumpWidget(
        _wrap(
          BookmarkFolderProvider(repository: repository),
          courseProvider: courseProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI 동선 생성하기'), findsOneWidget);

      await tester.tap(find.text('AI 동선 생성하기'));
      await tester.pumpAndSettle();

      expect(repository.routedFolderId, 'f1');
      expect(courseProvider.result?.course?.totalDistanceM, 1200);
      expect(find.text('route:/walking-course/result'), findsOneWidget);
    },
  );
}
