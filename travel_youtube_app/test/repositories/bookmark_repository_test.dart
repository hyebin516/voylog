import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/bookmark_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('listBookmarks maps the JSON bookmarks array into BookmarkModels', () async {
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
              'name': '해운대해수욕장',
              'address': '부산',
              'latitude': 35.1,
              'longitude': 129.1,
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

    final result = await BookmarkRepository().listBookmarks();

    expect(result, hasLength(1));
    expect(result.first.name, '해운대해수욕장');
    expect(adapter.lastOptions?.path, '/bookmarks');
    expect(adapter.lastOptions?.method, 'GET');
  });

  test('addBookmark posts the placeId and returns the new bookmarkId', () async {
    final adapter = FakeDioAdapter(
      statusCode: 201,
      body: {
        'success': true,
        'data': {'bookmarkId': 'new-id', 'placeId': 'p1', 'createdAt': '2026-01-01T00:00:00.000Z'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final bookmarkId = await BookmarkRepository().addBookmark('p1');

    expect(bookmarkId, 'new-id');
    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.data, {'placeId': 'p1'});
  });

  test('a 409 error response is surfaced as an ApiException with the backend error code', () async {
    final adapter = FakeDioAdapter(
      statusCode: 409,
      body: {
        'success': false,
        'error': {'code': 'BOOKMARK_EXISTS', 'message': 'This place is already bookmarked'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      BookmarkRepository().addBookmark('p1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'BOOKMARK_EXISTS')),
    );
  });
}
