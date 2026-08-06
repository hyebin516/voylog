import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('createFolder posts the name and maps the created folder (bookmarkCount starts at 0)', () async {
    final adapter = FakeDioAdapter(
      statusCode: 201,
      body: {
        'success': true,
        'data': {'folderId': 'f1', 'name': '제주 맛집', 'createdAt': '2026-01-01T00:00:00.000Z'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final folder = await BookmarkFolderRepository().createFolder('제주 맛집');

    expect(folder.folderId, 'f1');
    expect(folder.bookmarkCount, 0);
    expect(adapter.lastOptions?.path, '/bookmark-folders');
    expect(adapter.lastOptions?.data, {'name': '제주 맛집'});
  });

  test('listFolders maps the JSON folders array', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'folders': [
            {'folderId': 'f1', 'name': '제주 맛집', 'bookmarkCount': 2, 'createdAt': '2026-01-01T00:00:00.000Z'},
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final folders = await BookmarkFolderRepository().listFolders();

    expect(folders, hasLength(1));
    expect(folders.first.bookmarkCount, 2);
    expect(adapter.lastOptions?.method, 'GET');
  });

  test('deleteFolder calls DELETE /bookmark-folders/:id', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: const {});
    DioClient().dio.httpClientAdapter = adapter;

    await BookmarkFolderRepository().deleteFolder('f1');

    expect(adapter.lastOptions?.path, '/bookmark-folders/f1');
    expect(adapter.lastOptions?.method, 'DELETE');
  });

  test('listBookmarksInFolder maps the JSON bookmarks array', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'bookmarks': [
            {
              'bookmarkId': 'b1',
              'placeId': 'p1',
              'videoId': 'v1',
              'name': 'Place',
              'address': 'addr',
              'latitude': 35.0,
              'longitude': 129.0,
              'timestampSec': 10,
              'source': 'transcript',
              'confidence': 0.9,
              'bookmarkedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final bookmarks = await BookmarkFolderRepository().listBookmarksInFolder('f1');

    expect(bookmarks, hasLength(1));
    expect(adapter.lastOptions?.path, '/bookmark-folders/f1/bookmarks');
  });

  test('addBookmarkToFolder posts the bookmarkId', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: const {});
    DioClient().dio.httpClientAdapter = adapter;

    await BookmarkFolderRepository().addBookmarkToFolder('f1', 'b1');

    expect(adapter.lastOptions?.path, '/bookmark-folders/f1/bookmarks');
    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.data, {'bookmarkId': 'b1'});
  });

  test('removeBookmarkFromFolder calls DELETE on the nested resource', () async {
    final adapter = FakeDioAdapter(statusCode: 204, body: const {});
    DioClient().dio.httpClientAdapter = adapter;

    await BookmarkFolderRepository().removeBookmarkFromFolder('f1', 'b1');

    expect(adapter.lastOptions?.path, '/bookmark-folders/f1/bookmarks/b1');
    expect(adapter.lastOptions?.method, 'DELETE');
  });

  test('a 404 error response is surfaced as an ApiException with the backend error code', () async {
    final adapter = FakeDioAdapter(
      statusCode: 404,
      body: {
        'success': false,
        'error': {'code': 'FOLDER_NOT_FOUND', 'message': 'Bookmark folder not found'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      BookmarkFolderRepository().deleteFolder('missing'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FOLDER_NOT_FOUND')),
    );
  });
}
