import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A minimal [HttpClientAdapter] that returns a canned JSON response instead
/// of making a real network call, so repository tests exercise the real
/// [DioClient] (including its error-normalizing interceptor) without a
/// backend running. Install it via `DioClient().dio.httpClientAdapter = ...`.
class FakeDioAdapter implements HttpClientAdapter {
  FakeDioAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final encoded = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(
      encoded,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
