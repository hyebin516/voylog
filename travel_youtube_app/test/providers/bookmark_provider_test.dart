import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';
import 'package:travel_youtube_app/providers/bookmark_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

BookmarkModel _bookmark(String bookmarkId, String placeId) {
  return BookmarkModel(
    bookmarkId: bookmarkId,
    placeId: placeId,
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

class FakeBookmarkRepository extends BookmarkRepository {
  List<BookmarkModel> bookmarksToReturn = [];
  ApiException? listError;
  ApiException? addError;
  ApiException? removeError;
  final List<String> addCalls = [];
  final List<String> removeCalls = [];

  @override
  Future<List<BookmarkModel>> listBookmarks() async {
    if (listError != null) throw listError!;
    return bookmarksToReturn;
  }

  @override
  Future<String> addBookmark(String placeId) async {
    addCalls.add(placeId);
    if (addError != null) throw addError!;
    return 'new-bookmark-id';
  }

  @override
  Future<void> removeBookmark(String bookmarkId) async {
    removeCalls.add(bookmarkId);
    if (removeError != null) throw removeError!;
  }
}

void main() {
  late FakeBookmarkRepository repository;
  late BookmarkProvider provider;

  setUp(() {
    repository = FakeBookmarkRepository();
    provider = BookmarkProvider(repository: repository);
  });

  test('starts idle with no bookmarks', () {
    expect(provider.state, ViewState.idle);
    expect(provider.bookmarks, isEmpty);
  });

  group('loadBookmarks', () {
    test('transitions idle -> loading -> success and stores the bookmarks', () async {
      repository.bookmarksToReturn = [_bookmark('b1', 'p1'), _bookmark('b2', 'p2')];

      final future = provider.loadBookmarks();
      expect(provider.state, ViewState.loading);

      await future;

      expect(provider.state, ViewState.success);
      expect(provider.bookmarks, hasLength(2));
      expect(provider.errorMessage, isNull);
    });

    test('transitions to error and stores a friendly message on failure', () async {
      repository.listError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      await provider.loadBookmarks();

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, '네트워크 연결을 확인해 주세요.');
      expect(provider.bookmarks, isEmpty);
    });
  });

  group('isBookmarked', () {
    test('is true only for place ids present in the loaded bookmarks', () async {
      repository.bookmarksToReturn = [_bookmark('b1', 'p1')];
      await provider.loadBookmarks();

      expect(provider.isBookmarked('p1'), isTrue);
      expect(provider.isBookmarked('p2'), isFalse);
    });
  });

  group('toggleBookmark', () {
    test('adds a bookmark and reloads the list when the place was not bookmarked', () async {
      repository.bookmarksToReturn = [];
      await provider.loadBookmarks();
      repository.bookmarksToReturn = [_bookmark('new-bookmark-id', 'p1')];

      await provider.toggleBookmark('p1');

      expect(repository.addCalls, ['p1']);
      expect(provider.isBookmarked('p1'), isTrue);
    });

    test('removes a bookmark locally without a full reload when it was already bookmarked', () async {
      repository.bookmarksToReturn = [_bookmark('b1', 'p1'), _bookmark('b2', 'p2')];
      await provider.loadBookmarks();

      await provider.toggleBookmark('p1');

      expect(repository.removeCalls, ['b1']);
      expect(repository.addCalls, isEmpty);
      expect(provider.isBookmarked('p1'), isFalse);
      expect(provider.isBookmarked('p2'), isTrue);
    });

    test('surfaces a friendly error message when adding fails (e.g. already bookmarked elsewhere)', () async {
      repository.addError = const ApiException(code: 'BOOKMARK_EXISTS', message: 'boom');

      await provider.toggleBookmark('p1');

      expect(provider.errorMessage, '이미 북마크한 장소입니다.');
    });
  });
}
