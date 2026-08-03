import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/video_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('analyze posts the youtubeUrl and maps the response into a VideoModel with its places', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'videoId': 'v1',
          'title': 'My Trip',
          'isCached': false,
          'places': [
            {
              'placeId': 'p1',
              'name': 'Place',
              'timestampSec': 5,
              'latitude': 35.0,
              'longitude': 129.0,
              'address': 'addr',
              'source': 'transcript',
              'confidence': 0.8,
            },
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final video = await VideoRepository().analyze('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

    expect(video.videoId, 'v1');
    expect(video.places, hasLength(1));
    expect(adapter.lastOptions?.path, '/videos/analyze');
    expect(adapter.lastOptions?.data, {'youtubeUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'});
  });

  test('a 422 response (no transcript available) is surfaced as TRANSCRIPT_NOT_FOUND', () async {
    final adapter = FakeDioAdapter(
      statusCode: 422,
      body: {
        'success': false,
        'error': {'code': 'TRANSCRIPT_NOT_FOUND', 'message': 'Transcript is not available for this video'},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    await expectLater(
      VideoRepository().analyze('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TRANSCRIPT_NOT_FOUND')),
    );
  });

  test('a connection failure with no response is surfaced as NETWORK_ERROR', () async {
    DioClient().dio.httpClientAdapter = _ThrowingAdapter();

    await expectLater(
      VideoRepository().analyze('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR')),
    );
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw Exception('connection refused');
  }

  @override
  void close({bool force = false}) {}
}
