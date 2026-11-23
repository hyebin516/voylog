import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_folder_model.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/providers/bookmark_folder_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

BookmarkFolderModel _folder(String id, {int bookmarkCount = 0}) {
  return BookmarkFolderModel(
    folderId: id,
    name: 'Folder $id',
    bookmarkCount: bookmarkCount,
    createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );
}

BookmarkModel _bookmark(String bookmarkId) {
  return BookmarkModel(
    bookmarkId: bookmarkId,
    placeId: 'p1',
    videoId: 'v1',
    name: 'Place',
    address: 'addr',
    latitude: 35.0,
    longitude: 129.0,
    timestampSec: 10,
    source: 'transcript',
    confidence: 0.9,
    bookmarkedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  );
}

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  List<BookmarkFolderModel> foldersToReturn = [];
  ApiException? listError;
  ApiException? createError;
  ApiException? deleteError;

  List<BookmarkModel> folderBookmarksToReturn = [];
  ApiException? folderBookmarksError;
  ApiException? toggleError;
  final List<String> addCalls = [];
  final List<String> removeCalls = [];

  @override
  Future<List<BookmarkFolderModel>> listFolders() async {
    if (listError != null) throw listError!;
    return foldersToReturn;
  }

  @override
  Future<BookmarkFolderModel> createFolder(String name) async {
    if (createError != null) throw createError!;
    return BookmarkFolderModel(folderId: 'new-folder', name: name, bookmarkCount: 0, createdAt: DateTime(2026, 1, 1));
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<List<BookmarkModel>> listBookmarksInFolder(String folderId) async {
    if (folderBookmarksError != null) throw folderBookmarksError!;
    return folderBookmarksToReturn;
  }

  @override
  Future<void> addBookmarkToFolder(String folderId, String bookmarkId) async {
    addCalls.add(bookmarkId);
    if (toggleError != null) throw toggleError!;
  }

  @override
  Future<void> removeBookmarkFromFolder(String folderId, String bookmarkId) async {
    removeCalls.add(bookmarkId);
    if (toggleError != null) throw toggleError!;
  }
}

void main() {
  late FakeBookmarkFolderRepository repository;
  late BookmarkFolderProvider provider;

  setUp(() {
    repository = FakeBookmarkFolderRepository();
    provider = BookmarkFolderProvider(repository: repository);
  });

  test('starts idle with no folders', () {
    expect(provider.state, ViewState.idle);
    expect(provider.folders, isEmpty);
  });

  group('loadFolders', () {
    test('transitions to success and stores the folders', () async {
      repository.foldersToReturn = [_folder('f1'), _folder('f2')];

      await provider.loadFolders();

      expect(provider.state, ViewState.success);
      expect(provider.folders, hasLength(2));
    });

    test('transitions to error on failure', () async {
      repository.listError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      await provider.loadFolders();

      expect(provider.state, ViewState.error);
      expect(provider.folders, isEmpty);
    });
  });

  group('createFolder', () {
    test('prepends the new folder to the list on success', () async {
      repository.foldersToReturn = [_folder('f1')];
      await provider.loadFolders();

      final created = await provider.createFolder('New Folder');

      expect(created?.folderId, 'new-folder');
      expect(provider.folders.first.folderId, 'new-folder');
      expect(provider.folders, hasLength(2));
    });

    test('returns null and sets an error message on failure', () async {
      repository.createError = const ApiException(code: 'INVALID_REQUEST', message: 'boom');

      final created = await provider.createFolder('');

      expect(created, isNull);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('deleteFolder', () {
    test('removes the folder from the list on success', () async {
      repository.foldersToReturn = [_folder('f1'), _folder('f2')];
      await provider.loadFolders();

      final success = await provider.deleteFolder('f1');

      expect(success, isTrue);
      expect(provider.folders.map((f) => f.folderId), ['f2']);
    });

    test('keeps the folder and returns false on failure', () async {
      repository.foldersToReturn = [_folder('f1')];
      await provider.loadFolders();
      repository.deleteError = const ApiException(code: 'FOLDER_NOT_FOUND', message: 'boom');

      final success = await provider.deleteFolder('f1');

      expect(success, isFalse);
      expect(provider.folders, hasLength(1));
    });
  });

  group('loadFolderBookmarks / isInCurrentFolder', () {
    test('loads the folder bookmarks and tracks membership by id', () async {
      repository.folderBookmarksToReturn = [_bookmark('b1'), _bookmark('b2')];

      await provider.loadFolderBookmarks('f1');

      expect(provider.folderBookmarks, hasLength(2));
      expect(provider.isInCurrentFolder('b1'), isTrue);
      expect(provider.isInCurrentFolder('missing'), isFalse);
    });
  });

  group('toggleBookmarkInFolder', () {
    test('adds a bookmark not yet in the folder and reloads', () async {
      repository.folderBookmarksToReturn = [];
      await provider.loadFolderBookmarks('f1');
      repository.folderBookmarksToReturn = [_bookmark('b1')];

      await provider.toggleBookmarkInFolder('f1', 'b1');

      expect(repository.addCalls, ['b1']);
      expect(repository.removeCalls, isEmpty);
      expect(provider.isInCurrentFolder('b1'), isTrue);
    });

    test('removes a bookmark already in the folder and reloads', () async {
      repository.folderBookmarksToReturn = [_bookmark('b1')];
      await provider.loadFolderBookmarks('f1');
      repository.folderBookmarksToReturn = [];

      await provider.toggleBookmarkInFolder('f1', 'b1');

      expect(repository.removeCalls, ['b1']);
      expect(repository.addCalls, isEmpty);
      expect(provider.isInCurrentFolder('b1'), isFalse);
    });
  });

  test('clearFolderDetail resets the folder detail state', () async {
    repository.folderBookmarksToReturn = [_bookmark('b1')];
    await provider.loadFolderBookmarks('f1');

    provider.clearFolderDetail();

    expect(provider.folderBookmarks, isEmpty);
    expect(provider.detailState, ViewState.idle);
  });

  // 북마크 시트는 Provider를 거치지 않고 Repository를 직접 불러서 폴더에
  // 담는다. 그래서 담긴 사실을 Provider에 따로 알려주지 않으면, 북마크 탭의
  // 폴더 목록이 예전 숫자("장소 12곳")를 계속 보여준다.
  group('applyBookmarkCountDelta', () {
    test('해당 폴더의 개수만 올린다', () async {
      final repository = FakeBookmarkFolderRepository()
        ..foldersToReturn = [_folder('f1', bookmarkCount: 12), _folder('f2', bookmarkCount: 3)];
      final provider = BookmarkFolderProvider(repository: repository);
      await provider.loadFolders();

      provider.applyBookmarkCountDelta('f1', 1);

      expect(provider.folders.firstWhere((f) => f.folderId == 'f1').bookmarkCount, 13);
      expect(provider.folders.firstWhere((f) => f.folderId == 'f2').bookmarkCount, 3);
    });

    test('폴더에서 뺀 경우 개수를 내린다', () async {
      final repository = FakeBookmarkFolderRepository()
        ..foldersToReturn = [_folder('f1', bookmarkCount: 2)];
      final provider = BookmarkFolderProvider(repository: repository);
      await provider.loadFolders();

      provider.applyBookmarkCountDelta('f1', -1);

      expect(provider.folders.single.bookmarkCount, 1);
    });

    test('0 아래로는 내려가지 않는다', () async {
      // 시트와 서버 상태가 어긋나도 "장소 -1곳"이 화면에 뜨면 안 된다.
      final repository = FakeBookmarkFolderRepository()..foldersToReturn = [_folder('f1')];
      final provider = BookmarkFolderProvider(repository: repository);
      await provider.loadFolders();

      provider.applyBookmarkCountDelta('f1', -1);

      expect(provider.folders.single.bookmarkCount, 0);
    });

    test('목록에 없는 폴더면 아무 일도 하지 않는다', () async {
      final repository = FakeBookmarkFolderRepository()..foldersToReturn = [_folder('f1')];
      final provider = BookmarkFolderProvider(repository: repository);
      await provider.loadFolders();
      var notified = 0;
      provider.addListener(() => notified++);

      provider.applyBookmarkCountDelta('없는폴더', 1);

      expect(notified, 0);
      expect(provider.folders.single.bookmarkCount, 0);
    });
  });
}
