import 'package:dio/dio.dart';

import '../models/api_exception.dart';

/// Converts a DioException (already normalized by DioClient's interceptor)
/// into the ApiException it carries, so repositories can rethrow a
/// consistent, typed error for Providers/UI to catch.
Never throwApiException(DioException error) {
  final wrapped = error.error;
  if (wrapped is ApiException) {
    throw wrapped;
  }
  throw const ApiException(code: 'UNKNOWN_ERROR', message: 'Unknown error');
}
