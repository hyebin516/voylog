import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/models/start_point_model.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/bookmark_folder_repository.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const StartPointModel _startPoint = StartPointModel(
  name: '제주공항',
  latitude: 33.51,
  longitude: 126.49,
);

const WalkingCourseModel _emptyResult = WalkingCourseModel(
  course: null,
  recommendations: [],
);

const WalkingCourseRouteModel _route = WalkingCourseRouteModel(
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 2119,
  totalDurationSec: 1897,
  routeData: [
    RoutePointModel(
      order: 0,
      type: 'hotel',
      hotelId: 'region-center',
      placeId: null,
      name: '제주',
      latitude: 33.5,
      longitude: 126.5,
    ),
  ],
);

const WalkingCourseModel _resultWithCourse = WalkingCourseModel(
  course: _route,
  recommendations: [],
);

class FakeWalkingCourseRepository extends WalkingCourseRepository {
  WalkingCourseModel? resultToReturn;
  ApiException? error;
  String? lastRegion;
  String? lastMood;
  String? lastWalkDuration;
  StartPointModel? lastStartPoint;
  List<String> lastAvoidPlaceIds = const [];
  int generateCalls = 0;

  @override
  Future<WalkingCourseModel> generate({
    required String region,
    required DateTime localTime,
    String? mood,
    String? walkDuration,
    StartPointModel? startPoint,
    List<String> avoidPlaceIds = const [],
  }) async {
    generateCalls++;
    lastRegion = region;
    lastMood = mood;
    lastWalkDuration = walkDuration;
    lastStartPoint = startPoint;
    lastAvoidPlaceIds = avoidPlaceIds;
    if (error != null) throw error!;
    return resultToReturn ?? _emptyResult;
  }
}

class FakeBookmarkFolderRepository extends BookmarkFolderRepository {
  final List<String> routedFolderIds = [];

  @override
  Future<WalkingCourseModel> createRoute(String folderId) async {
    routedFolderIds.add(folderId);
    return _emptyResult;
  }
}

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  ApiException? error;
  String? lastRegion;
  WalkingCourseRouteModel? lastCourse;

  @override
  Future<SavedWalkingCourseModel> save({
    required String region,
    required WalkingCourseRouteModel course,
  }) async {
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
    provider = WalkingCourseProvider(
      repository: repository,
      savedCourseRepository: savedRepository,
    );
  });

  test('starts idle with no result', () {
    expect(provider.state, ViewState.idle);
    expect(provider.result, isNull);
    expect(provider.region, isNull);
  });

  test(
    'generate transitions idle -> loading -> success and stores the region and result',
    () async {
      repository.resultToReturn = _emptyResult;

      final future = provider.generate('제주');
      expect(provider.isLoading, isTrue);
      await future;

      expect(provider.state, ViewState.success);
      expect(provider.region, '제주');
      expect(repository.lastRegion, '제주');
      expect(provider.result, _emptyResult);
    },
  );

  test(
    'generate forwards mood and walkDuration to the repository when provided',
    () async {
      repository.resultToReturn = _emptyResult;

      await provider.generate('제주', mood: '힙한', walkDuration: '2~3시간');

      expect(repository.lastMood, '힙한');
      expect(repository.lastWalkDuration, '2~3시간');
    },
  );

  test(
    'generate leaves mood and walkDuration null when not provided',
    () async {
      repository.resultToReturn = _emptyResult;

      await provider.generate('제주');

      expect(repository.lastMood, isNull);
      expect(repository.lastWalkDuration, isNull);
    },
  );

  test(
    'generate transitions to error and stores a friendly message on failure',
    () async {
      repository.error = const ApiException(
        code: 'GEOCODING_FAILED',
        message: 'boom',
      );

      await provider.generate('존재하지않는지역');

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, '위치 정보를 가져오지 못했습니다.');
      expect(
        provider.region,
        '존재하지않는지역',
      ); // kept so the error view can retry the same region
    },
  );

  test(
    'reset clears the region, result, saved state, and error, returning to idle',
    () async {
      repository.resultToReturn = _emptyResult;
      await provider.generate('제주');

      provider.reset();

      expect(provider.state, ViewState.idle);
      expect(provider.region, isNull);
      expect(provider.result, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.saved, isFalse);
    },
  );

  group('regenerate', () {
    test(
      'regenerate re-runs generate with the last-used region, mood, and walkDuration',
      () async {
        repository.resultToReturn = _emptyResult;
        await provider.generate('제주', mood: '힙한', walkDuration: '2~3시간');

        await provider.regenerate();

        expect(repository.generateCalls, 2);
        expect(repository.lastRegion, '제주');
        expect(repository.lastMood, '힙한');
        expect(repository.lastWalkDuration, '2~3시간');
      },
    );

    test('regenerate does nothing when no region has been set yet', () async {
      await provider.regenerate();

      expect(repository.generateCalls, 0);
      expect(provider.state, ViewState.idle);
    });

    test(
      'regenerateWithStartPoint re-runs generate anchored on that point, keeping the other filters',
      () async {
        repository.resultToReturn = _emptyResult;
        await provider.generate('제주', mood: '힙한', walkDuration: '2~3시간');
        expect(repository.lastStartPoint, isNull);

        await provider.regenerateWithStartPoint(_startPoint);

        expect(repository.generateCalls, 2);
        expect(repository.lastRegion, '제주');
        expect(repository.lastMood, '힙한');
        expect(repository.lastWalkDuration, '2~3시간');
        expect(repository.lastStartPoint?.name, '제주공항');
      },
    );

    test('regenerate keeps the start point chosen for the previous run', () async {
      repository.resultToReturn = _emptyResult;
      await provider.generate('제주', startPoint: _startPoint);

      await provider.regenerate();

      expect(repository.lastStartPoint?.name, '제주공항');
    });

    test('regenerate asks to avoid the places of the course on screen', () async {
      repository.resultToReturn = const WalkingCourseModel(
        course: WalkingCourseRouteModel(
          routeType: 'roundTrip',
          transportMode: 'walk',
          totalDistanceM: 900,
          totalDurationSec: 600,
          routeData: [
            RoutePointModel(order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주', latitude: 33.5, longitude: 126.5),
            RoutePointModel(order: 1, type: 'place', hotelId: null, placeId: 'p1', name: 'A', latitude: 33.51, longitude: 126.5),
            RoutePointModel(order: 2, type: 'place', hotelId: null, placeId: 'kakao:2', name: 'B', latitude: 33.52, longitude: 126.5),
          ],
        ),
        recommendations: [],
      );
      await provider.generate('제주');
      expect(repository.lastAvoidPlaceIds, isEmpty);

      await provider.regenerate();

      expect(repository.lastAvoidPlaceIds, ['p1', 'kakao:2']);
    });
  });

  group('save', () {
    test(
      'saves the generated course under the current region and marks it saved',
      () async {
        repository.resultToReturn = _resultWithCourse;
        await provider.generate('제주');

        final success = await provider.save();

        expect(success, isTrue);
        expect(provider.saved, isTrue);
        expect(provider.isSaving, isFalse);
        expect(savedRepository.lastRegion, '제주');
        expect(savedRepository.lastCourse, _route);
      },
    );

    test(
      'does nothing and returns false when there is no course to save',
      () async {
        repository.resultToReturn = _emptyResult;
        await provider.generate('제주');

        final success = await provider.save();

        expect(success, isFalse);
        expect(provider.saved, isFalse);
        expect(savedRepository.lastCourse, isNull);
      },
    );

    test(
      'sets a friendly error message and returns false on failure',
      () async {
        repository.resultToReturn = _resultWithCourse;
        await provider.generate('제주');
        savedRepository.error = const ApiException(
          code: 'NETWORK_ERROR',
          message: 'boom',
        );

        final success = await provider.save();

        expect(success, isFalse);
        expect(provider.saved, isFalse);
        expect(provider.saveErrorMessage, '네트워크 연결을 확인해 주세요.');
      },
    );
  });

  group('generateFromBookmarkFolder', () {
    test('routes the folder, and regenerating re-routes it instead of searching its name', () async {
      final regionRepository = FakeWalkingCourseRepository();
      final folderRepository = FakeBookmarkFolderRepository();
      final provider = WalkingCourseProvider(
        repository: regionRepository,
        folderRepository: folderRepository,
      );

      await provider.generateFromBookmarkFolder(folderId: 'f1', folderName: '부산 코스');
      expect(provider.state, ViewState.success);
      expect(provider.region, '부산 코스');
      expect(provider.isFromBookmarkFolder, isTrue);

      await provider.regenerate();

      expect(folderRepository.routedFolderIds, ['f1', 'f1']);
      expect(regionRepository.generateCalls, 0);
    });

    test('ignores a start point: the folder name is not a searchable region', () async {
      final regionRepository = FakeWalkingCourseRepository();
      final provider = WalkingCourseProvider(
        repository: regionRepository,
        folderRepository: FakeBookmarkFolderRepository(),
      );
      await provider.generateFromBookmarkFolder(folderId: 'f1', folderName: 'ㄹ');

      await provider.regenerateWithStartPoint(_startPoint);

      expect(regionRepository.generateCalls, 0);
    });

    test('a later region search is a region course again', () async {
      final provider = WalkingCourseProvider(
        repository: FakeWalkingCourseRepository(),
        folderRepository: FakeBookmarkFolderRepository(),
      );
      await provider.generateFromBookmarkFolder(folderId: 'f1', folderName: 'ㄹ');

      await provider.generate('제주');

      expect(provider.isFromBookmarkFolder, isFalse);
    });
  });
}
