import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/start_point_model.dart';
import '../models/walking_course_model.dart';
import '../repositories/saved_walking_course_repository.dart';
import '../repositories/walking_course_repository.dart';
import '../utils/view_state.dart';

class WalkingCourseProvider extends ChangeNotifier {
  final WalkingCourseRepository _repository;
  final SavedWalkingCourseRepository _savedCourseRepository;

  WalkingCourseProvider({
    WalkingCourseRepository? repository,
    SavedWalkingCourseRepository? savedCourseRepository,
  }) : _repository = repository ?? WalkingCourseRepository(),
       _savedCourseRepository =
           savedCourseRepository ?? SavedWalkingCourseRepository();

  ViewState _state = ViewState.idle;
  WalkingCourseModel? _result;
  String? _errorMessage;
  String? _region;
  String? _mood;
  String? _walkDuration;
  StartPointModel? _startPoint;

  bool _isSaving = false;
  bool _saved = false;
  String? _saveErrorMessage;

  ViewState get state => _state;
  WalkingCourseModel? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get region => _region;
  bool get isLoading => _state == ViewState.loading;

  bool get isSaving => _isSaving;
  bool get saved => _saved;
  String? get saveErrorMessage => _saveErrorMessage;

  Future<void> generate(
    String region, {
    String? mood,
    String? walkDuration,
    StartPointModel? startPoint,
    List<String> avoidPlaceIds = const [],
  }) async {
    _region = region;
    _mood = mood;
    _walkDuration = walkDuration;
    _startPoint = startPoint;
    _state = ViewState.loading;
    _errorMessage = null;
    _saved = false;
    _saveErrorMessage = null;
    notifyListeners();

    try {
      _result = await _repository.generate(
        region: region,
        localTime: DateTime.now(),
        mood: mood,
        walkDuration: walkDuration,
        startPoint: startPoint,
        avoidPlaceIds: avoidPlaceIds,
      );
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  /// Regenerates the course for the same region, reusing whichever
  /// mood/walkDuration filters and start point were last used to generate it.
  Future<void> regenerate() async {
    final region = _region;
    if (region == null) return;
    await generate(
      region,
      mood: _mood,
      walkDuration: _walkDuration,
      startPoint: _startPoint,
      // Without this the same filters rank the same places first, so "다시
      // 생성" kept returning the course the user was trying to move away from.
      avoidPlaceIds: _currentPlaceIds(),
    );
  }

  List<String> _currentPlaceIds() {
    final course = _result?.course;
    if (course == null) return const [];
    return course.routeData
        .where((p) => !p.isHotel && p.placeId != null)
        .map((p) => p.placeId!)
        .toList();
  }

  /// Re-runs generation anchored on [startPoint] (the FR-17 course
  /// otherwise starts and ends at the region's center point, which isn't a
  /// real place).
  Future<void> regenerateWithStartPoint(StartPointModel startPoint) async {
    final region = _region;
    if (region == null) return;
    await generate(
      region,
      mood: _mood,
      walkDuration: _walkDuration,
      startPoint: startPoint,
    );
  }

  Future<bool> save() async {
    final course = _result?.course;
    final region = _region;
    if (course == null || region == null) return false;

    _isSaving = true;
    _saveErrorMessage = null;
    notifyListeners();

    try {
      await _savedCourseRepository.save(region: region, course: course);
      _isSaving = false;
      _saved = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isSaving = false;
      _saveErrorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _region = null;
    _result = null;
    _state = ViewState.idle;
    _errorMessage = null;
    _isSaving = false;
    _saved = false;
    _saveErrorMessage = null;
    notifyListeners();
  }
}
