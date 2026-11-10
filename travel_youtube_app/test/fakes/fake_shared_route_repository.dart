import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/shared_route_model.dart';
import 'package:travel_youtube_app/repositories/shared_route_repository.dart';

/// Stands in for [SharedRouteRepository] so widget tests never build a Dio
/// client. Only the calls a test actually drives are recorded; the rest
/// throw, so an unexpected network call shows up as a failure instead of
/// silently passing.
class FakeSharedRouteRepository implements SharedRouteRepository {
  final List<({String id, String reason, String? detail})> reports = [];
  ApiException? reportError;

  @override
  Future<void> report(String sharedRouteId, {required String reason, String? detail}) async {
    if (reportError != null) throw reportError!;
    reports.add((id: sharedRouteId, reason: reason, detail: detail));
  }

  @override
  Future<List<SharedRouteModel>> getFeed({int? limit}) =>
      throw UnimplementedError('getFeed is not used in these tests');

  @override
  Future<void> like(String sharedRouteId) =>
      throw UnimplementedError('like is not used in these tests');

  @override
  Future<void> unlike(String sharedRouteId) =>
      throw UnimplementedError('unlike is not used in these tests');

  @override
  Future<SharedRouteModel> updateTitle(String sharedRouteId, String title) =>
      throw UnimplementedError('updateTitle is not used in these tests');

  @override
  Future<void> unpublish(String sharedRouteId) =>
      throw UnimplementedError('unpublish is not used in these tests');
}
