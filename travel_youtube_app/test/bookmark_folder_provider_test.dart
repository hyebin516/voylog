import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/models/place_search_result_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';

BookmarkModel _bookmark(String bookmarkId) {
  return BookmarkModel(
    bookmarkId: bookmarkId,
    placeId: 'p-$bookmarkId',
    videoId: 'v1',
    name: bookmarkId,
    address: 'addr',
    latitude: 35.8,
    longitude: 127.1,
    timestampSec: 10,
    source: 'transcript',
    confidence: 0.9,
    bookmarkedAt: DateTime(2026, 1, 1),
  );
}

class _FakeRepository extends BookmarkFolderRepository {
  _FakeRepository(this.foldersToReturn);

  List<BookmarkFolderModel> foldersToReturn;
  List<BookmarkModel> folderBookmarks = [];

  @override
  Future<List<BookmarkFolderModel>> listFolders() async => foldersToReturn;

  @override
  Future<List<BookmarkModel>> listBookmarksInFolder(String folderId) async => folderBookmarks;

  @override
  Future<void> addBookmarkToFolder(String folderId, String bookmarkId) async {
    folderBookmarks = [...folderBookmarks, _bookmark(bookmarkId)];
  }

  @override
  Future<void> removeBookmarkFromFolder(String folderId, String bookmarkId) async {
    folderBookmarks = folderBookmarks.where((b) => b.bookmarkId != bookmarkId).toList();
  }

  @override
  Future<void> addSearchedPlaceToFolder(String folderId, PlaceSearchResultModel place) async {
    folderBookmarks = [...folderBookmarks, _bookmark(place.name)];
  }
}

BookmarkFolderModel _folder(String id, String name, int count) {
  return BookmarkFolderModel(
    folderId: id,
    name: name,
    bookmarkCount: count,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // 폴더 목록의 장소 개수는 listFolders()가 한 번 받아온 값이다. 폴더에
  // 장소를 담는 경로가 그 값을 갱신하지 않아, 여행 날짜를 만들 때 고르는
  // 폴더 화면에서 방금 4곳을 담은 폴더가 "장소 0곳"으로 보였다.
  group('폴더에 장소를 담으면 목록의 개수도 따라간다', () {
    test('북마크를 토글하면 그 폴더의 개수만 바뀐다', () async {
      final repo = _FakeRepository([
        _folder('f1', '전주', 0),
        _folder('f2', '부산', 3),
      ]);
      final provider = BookmarkFolderProvider(repository: repo);

      await provider.loadFolders();
      await provider.loadFolderBookmarks('f1');
      expect(provider.folders.first.bookmarkCount, 0);

      await provider.toggleBookmarkInFolder('f1', 'b1');
      await provider.toggleBookmarkInFolder('f1', 'b2');

      expect(provider.folders.firstWhere((f) => f.folderId == 'f1').bookmarkCount, 2);
      // 건드리지 않은 폴더는 그대로. 북마크 하나가 여러 폴더에 속할 수 있으므로
      // 다른 폴더의 개수를 함께 움직이면 틀린다.
      expect(provider.folders.firstWhere((f) => f.folderId == 'f2').bookmarkCount, 3);
    });

    test('빼면 개수도 줄어든다', () async {
      final repo = _FakeRepository([_folder('f1', '전주', 0)]);
      final provider = BookmarkFolderProvider(repository: repo);

      await provider.loadFolders();
      await provider.loadFolderBookmarks('f1');
      await provider.toggleBookmarkInFolder('f1', 'b1');
      expect(provider.folders.first.bookmarkCount, 1);

      await provider.toggleBookmarkInFolder('f1', 'b1');
      expect(provider.folders.first.bookmarkCount, 0);
    });

    test('검색해서 담은 장소도 개수에 반영된다', () async {
      final repo = _FakeRepository([_folder('f1', '전주', 0)]);
      final provider = BookmarkFolderProvider(repository: repo);

      await provider.loadFolders();
      await provider.loadFolderBookmarks('f1');

      final added = await provider.addSearchResultToFolder(
        'f1',
        const PlaceSearchResultModel(
          origin: 'kakao',
          name: '전주한옥마을',
          kakaoPlaceId: '123',
          latitude: 35.81,
          longitude: 127.15,
        ),
      );

      expect(added, isTrue);
      expect(provider.folders.first.bookmarkCount, 1);
    });
  });
}
