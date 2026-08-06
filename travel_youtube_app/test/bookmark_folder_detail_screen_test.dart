import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
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

  @override
  Future<List<BookmarkModel>> listBookmarksInFolder(String folderId) async => bookmarksToReturn;

  @override
  Future<void> removeBookmarkFromFolder(String folderId, String bookmarkId) async {
    removeCalls.add(bookmarkId);
    bookmarksToReturn = bookmarksToReturn.where((b) => b.bookmarkId != bookmarkId).toList();
  }

  @override
  Future<List<BookmarkFolderModel>> listFolders() async => [];
}

Widget _wrap(BookmarkFolderProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const BookmarkFolderDetailScreen(folderId: 'f1'),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('picker'))),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when the folder has no bookmarks yet', (tester) async {
    final repository = FakeBookmarkFolderRepository();
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('이 폴더에 담긴 북마크가 없습니다.'), findsOneWidget);
  });

  testWidgets('lists the bookmarks currently in the folder', (tester) async {
    final repository = FakeBookmarkFolderRepository()..bookmarksToReturn = [_bookmark('b1', '해운대해수욕장')];
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('해운대해수욕장'), findsOneWidget);
  });

  testWidgets('tapping the remove icon takes the bookmark out of the folder', (tester) async {
    final repository = FakeBookmarkFolderRepository()..bookmarksToReturn = [_bookmark('b1', '해운대해수욕장')];
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, ['b1']);
    expect(find.text('해운대해수욕장'), findsNothing);
  });

  testWidgets('tapping the add button navigates to the picker screen', (tester) async {
    final repository = FakeBookmarkFolderRepository();
    await tester.pumpWidget(_wrap(BookmarkFolderProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('picker'), findsOneWidget);
  });
}
