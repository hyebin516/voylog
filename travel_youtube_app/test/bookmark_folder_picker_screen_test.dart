import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/place_search_result_model.dart';
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

  List<PlaceSearchResultModel> searchResultsToReturn = [];
  final List<String> searchQueries = [];
  final List<PlaceSearchResultModel> addedPlaces = [];

  @override
  Future<List<PlaceSearchResultModel>> searchPlaces(String query) async {
    searchQueries.add(query);
    return searchResultsToReturn;
  }

  @override
  Future<void> addSearchedPlaceToFolder(String folderId, PlaceSearchResultModel place) async {
    addedPlaces.add(place);
    folderBookmarksToReturn = [...folderBookmarksToReturn, _bookmark('b-new', place.name)];
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


  testWidgets('검색하면 내 북마크와 카카오 결과를 함께 보여준다', (tester) async {
    // 검색창 하나로 "담아둔 곳"과 "새로 찾는 곳"을 모두 다룬다.
    final folderRepository = FakeBookmarkFolderRepository()
      ..searchResultsToReturn = const [
        PlaceSearchResultModel(origin: 'bookmark', bookmarkId: 'b1', placeId: 'p1', name: '전주한옥마을'),
        PlaceSearchResultModel(
          origin: 'kakao',
          kakaoPlaceId: '1234',
          name: '전주객사',
          latitude: 35.8,
          longitude: 127.1,
        ),
      ];
    final folderProvider = BookmarkFolderProvider(repository: folderRepository);

    await tester.pumpWidget(_wrap(BookmarkProvider(repository: FakeBookmarkRepository()), folderProvider));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('folderPlaceSearchField')), '전주');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(folderRepository.searchQueries, ['전주']);
    expect(find.text('전주한옥마을'), findsOneWidget);
    expect(find.text('전주객사'), findsOneWidget);
    expect(find.text('담아둔 곳'), findsOneWidget); // 북마크 쪽에만 붙는다
  });

  testWidgets('카카오 결과를 누르면 폴더에 바로 담긴다', (tester) async {
    // 전에는 어느 영상에선가 추출된 장소만 담을 수 있었다.
    final folderRepository = FakeBookmarkFolderRepository()
      ..searchResultsToReturn = const [
        PlaceSearchResultModel(
          origin: 'kakao',
          kakaoPlaceId: '1234',
          name: '전주객사',
          address: '전북 전주시',
          latitude: 35.8,
          longitude: 127.1,
        ),
      ];
    final folderProvider = BookmarkFolderProvider(repository: folderRepository);

    await tester.pumpWidget(_wrap(BookmarkProvider(repository: FakeBookmarkRepository()), folderProvider));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('folderPlaceSearchField')), '객사');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('전주객사'));
    await tester.pumpAndSettle();

    expect(folderRepository.addedPlaces.single.kakaoPlaceId, '1234');
    expect(find.textContaining('폴더에 담았어요'), findsOneWidget);
  });
}
