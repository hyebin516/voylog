import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/providers/saved_walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

SavedWalkingCourseModel _course(String id, String region) {
  return SavedWalkingCourseModel(
    savedCourseId: id,
    region: region,
    routeType: 'roundTrip',
    transportMode: 'walk',
    totalDistanceM: 2000,
    totalDurationSec: 1800,
    routeData: const [],
    createdAt: DateTime(2026, 8, 28),
  );
}

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  List<SavedWalkingCourseModel> coursesToReturn = [];
  ApiException? listError;
  ApiException? deleteError;
  final List<String> deleteCalls = [];

  @override
  Future<List<SavedWalkingCourseModel>> list() async {
    if (listError != null) throw listError!;
    return coursesToReturn;
  }

  @override
  Future<void> delete(String savedCourseId) async {
    deleteCalls.add(savedCourseId);
    if (deleteError != null) throw deleteError!;
  }
}

void main() {
  late FakeSavedWalkingCourseRepository repository;
  late SavedWalkingCourseProvider provider;

  setUp(() {
    repository = FakeSavedWalkingCourseRepository();
    provider = SavedWalkingCourseProvider(repository: repository);
  });

  test('starts idle with no courses', () {
    expect(provider.state, ViewState.idle);
    expect(provider.courses, isEmpty);
  });

  test('loadCourses transitions to success and stores the courses', () async {
    repository.coursesToReturn = [_course('sc1', '제주')];

    await provider.loadCourses();

    expect(provider.state, ViewState.success);
    expect(provider.courses, hasLength(1));
    expect(provider.courses.first.region, '제주');
  });

  test('loadCourses transitions to error with a friendly message on failure', () async {
    repository.listError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');

    await provider.loadCourses();

    expect(provider.state, ViewState.error);
    expect(provider.errorMessage, '네트워크 연결을 확인해 주세요.');
  });

  group('deleteCourse', () {
    test('removes the course from the list and returns true on success', () async {
      repository.coursesToReturn = [_course('sc1', '제주'), _course('sc2', '부산')];
      await provider.loadCourses();

      final success = await provider.deleteCourse('sc1');

      expect(success, isTrue);
      expect(repository.deleteCalls, ['sc1']);
      expect(provider.courses.map((c) => c.savedCourseId), ['sc2']);
    });

    test('keeps the course and returns false on failure', () async {
      repository.coursesToReturn = [_course('sc1', '제주')];
      await provider.loadCourses();
      repository.deleteError = const ApiException(code: 'SAVED_COURSE_NOT_FOUND', message: 'boom');

      final success = await provider.deleteCourse('sc1');

      expect(success, isFalse);
      expect(provider.courses, hasLength(1));
    });
  });
}
