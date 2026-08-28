import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const WalkingCourseModel _emptyResult = WalkingCourseModel(course: null, recommendations: []);

class FakeWalkingCourseRepository extends WalkingCourseRepository {
  WalkingCourseModel? resultToReturn;
  ApiException? error;
  String? lastRegion;

  @override
  Future<WalkingCourseModel> generate({required String region, required DateTime localTime}) async {
    lastRegion = region;
    if (error != null) throw error!;
    return resultToReturn ?? _emptyResult;
  }
}

void main() {
  late FakeWalkingCourseRepository repository;
  late WalkingCourseProvider provider;

  setUp(() {
    repository = FakeWalkingCourseRepository();
    provider = WalkingCourseProvider(repository: repository);
  });

  test('starts idle with no result', () {
    expect(provider.state, ViewState.idle);
    expect(provider.result, isNull);
    expect(provider.region, isNull);
  });

  test('generate transitions idle -> loading -> success and stores the region and result', () async {
    repository.resultToReturn = _emptyResult;

    final future = provider.generate('제주');
    expect(provider.isLoading, isTrue);
    await future;

    expect(provider.state, ViewState.success);
    expect(provider.region, '제주');
    expect(repository.lastRegion, '제주');
    expect(provider.result, _emptyResult);
  });

  test('generate transitions to error and stores a friendly message on failure', () async {
    repository.error = const ApiException(code: 'GEOCODING_FAILED', message: 'boom');

    await provider.generate('존재하지않는지역');

    expect(provider.state, ViewState.error);
    expect(provider.errorMessage, '위치 정보를 가져오지 못했습니다.');
    expect(provider.region, '존재하지않는지역'); // kept so the error view can retry the same region
  });

  test('reset clears the region, result, and error, returning to idle', () async {
    repository.resultToReturn = _emptyResult;
    await provider.generate('제주');

    provider.reset();

    expect(provider.state, ViewState.idle);
    expect(provider.region, isNull);
    expect(provider.result, isNull);
    expect(provider.errorMessage, isNull);
  });
}
