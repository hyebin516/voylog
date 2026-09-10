import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/saved_walking_course_model.dart';
import '../repositories/saved_walking_course_repository.dart';
import '../utils/view_state.dart';

class SavedWalkingCourseProvider extends ChangeNotifier {
  final SavedWalkingCourseRepository _repository;

  SavedWalkingCourseProvider({SavedWalkingCourseRepository? repository})
      : _repository = repository ?? SavedWalkingCourseRepository();

  ViewState _state = ViewState.idle;
  List<SavedWalkingCourseModel> _courses = [];
  String? _errorMessage;

  ViewState get state => _state;
  List<SavedWalkingCourseModel> get courses => _courses;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  Future<void> loadCourses() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _courses = await _repository.list();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<bool> deleteCourse(String savedCourseId) async {
    try {
      await _repository.delete(savedCourseId);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    _courses = _courses.where((c) => c.savedCourseId != savedCourseId).toList();
    notifyListeners();
    return true;
  }

  Future<bool> publishCourse({required String savedCourseId, required String title}) async {
    try {
      await _repository.publish(savedCourseId: savedCourseId, title: title);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }
  }
}
