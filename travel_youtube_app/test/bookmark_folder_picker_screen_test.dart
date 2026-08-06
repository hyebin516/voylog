import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/screens/bookmark_folder_picker_screen.dart';

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

class FakeBookmarkRepository extends BookmarkRepository {
  List<BookmarkModel> bookmarksToReturn = [];

  @override
  Future<List<BookmarkModel>> listBookmarks() async => bookmarksToReturn;
}

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  List<BookmarkModel> folderBookmarksToReturn = [];
  final List<String> addCalls = [];
  final List<String> removeCalls = [];

  @override
  Future<List<BookmarkModel>> listBookmarksInFolder(String folderId) async => folderBookmarksToReturn;

  @override
  Future<void> addBookmarkToFolder(String folderId, String bookmarkId) async {
    addCalls.add(bookmarkId);
    folderBookmarksToReturn = [...folderBookmarksToReturn, _bookmark(bookmarkId, bookmarkId)];
  }

  @override
  Future<void> removeBookmarkFromFolder(String folderId, String bookmarkId) async {
    removeCalls.add(bookmarkId);
    folderBookmarksToReturn = folderBookmarksToReturn.where((b) => b.bookmarkId != bookmarkId).toList();
  }
}

Widget _wrap(BookmarkProvider bookmarkProvider, BookmarkFolderProvider folderProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: bookmarkProvider),
      ChangeNotifierProvider.value(value: folderProvider),
    ],
    child: const MaterialApp(home: BookmarkFolderPickerScreen(folderId: 'f1')),
  );
}

void main() {
  testWidgets('shows every bookmark with its current folder membership', (tester) async {
    final bookmarkRepository = FakeBookmarkRepository()
      ..bookmarksToReturn = [_bookmark('b1', '해운대해수욕장'), _bookmark('b2', '광안리')];
    final folderRepository = FakeBookmarkFolderRepository()..folderBookmarksToReturn = [_bookmark('b1', '해운대해수욕장')];
    final folderProvider = BookmarkFolderProvider(repository: folderRepository);
    await folderProvider.loadFolderBookmarks('f1');

    await tester.pumpWidget(_wrap(BookmarkProvider(repository: bookmarkRepository), folderProvider));
    await tester.pumpAndSettle();

    final checkboxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(checkboxes[0].value, isTrue);
    expect(checkboxes[1].value, isFalse);
  });

  testWidgets('tapping an unchecked bookmark adds it to the folder', (tester) async {
    final bookmarkRepository = FakeBookmarkRepository()..bookmarksToReturn = [_bookmark('b1', '해운대해수욕장')];
    final folderRepository = FakeBookmarkFolderRepository();
    final folderProvider = BookmarkFolderProvider(repository: folderRepository);
    await folderProvider.loadFolderBookmarks('f1');

    await tester.pumpWidget(_wrap(BookmarkProvider(repository: bookmarkRepository), folderProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    expect(folderRepository.addCalls, ['b1']);
  });
}
