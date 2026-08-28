import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const WalkingCourseModel _emptyResult = WalkingCourseModel(course: null, recommendations: []);

const WalkingCourseRouteModel _route = WalkingCourseRouteModel(
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 2119,
  totalDurationSec: 1897,
  routeData: [
    RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주', latitude: 33.5, longitude: 126.5),
  ],
);

const WalkingCourseModel _resultWithCourse = WalkingCourseModel(course: _route, recommendations: []);

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

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  ApiException? error;
  String? lastRegion;
  WalkingCourseRouteModel? lastCourse;

  @override
  Future<SavedWalkingCourseModel> save({required String region, required WalkingCourseRouteModel course}) async {
    lastRegion = region;
    lastCourse = course;
    if (error != null) throw error!;
    return SavedWalkingCourseModel(
      savedCourseId: 'sc1',
      region: region,
      routeType: course.routeType,
      transportMode: course.transportMode,
      totalDistanceM: course.totalDistanceM,
      totalDurationSec: course.totalDurationSec,
      routeData: course.routeData,
      createdAt: DateTime(2026, 8, 28),
    );
  }
}

void main() {
  late FakeWalkingCourseRepository repository;
  late FakeSavedWalkingCourseRepository savedRepository;
  late WalkingCourseProvider provider;

  setUp(() {
    repository = FakeWalkingCourseRepository();
    savedRepository = FakeSavedWalkingCourseRepository();
    provider = WalkingCourseProvider(repository: repository, savedCourseRepository: savedRepository);
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

  test('reset clears the region, result, saved state, and error, returning to idle', () async {
    repository.resultToReturn = _emptyResult;
    await provider.generate('제주');

    provider.reset();

    expect(provider.state, ViewState.idle);
    expect(provider.region, isNull);
    expect(provider.result, isNull);
    expect(provider.errorMessage, isNull);
    expect(provider.saved, isFalse);
  });

  group('save', () {
    test('saves the generated course under the current region and marks it saved', () async {
      repository.resultToReturn = _resultWithCourse;
      await provider.generate('제주');

      final success = await provider.save();

      expect(success, isTrue);
      expect(provider.saved, isTrue);
      expect(provider.isSaving, isFalse);
      expect(savedRepository.lastRegion, '제주');
      expect(savedRepository.lastCourse, _route);
    });

    test('does nothing and returns false when there is no course to save', () async {
      repository.resultToReturn = _emptyResult;
      await provider.generate('제주');

      final success = await provider.save();

      expect(success, isFalse);
      expect(provider.saved, isFalse);
      expect(savedRepository.lastCourse, isNull);
    });

    test('sets a friendly error message and returns false on failure', () async {
      repository.resultToReturn = _resultWithCourse;
      await provider.generate('제주');
      savedRepository.error = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

      final success = await provider.save();

      expect(success, isFalse);
      expect(provider.saved, isFalse);
      expect(provider.saveErrorMessage, '네트워크 연결을 확인해 주세요.');
    });
  });
}
