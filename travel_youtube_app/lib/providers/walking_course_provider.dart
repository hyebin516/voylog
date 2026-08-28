import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/walking_course_model.dart';
import '../repositories/walking_course_repository.dart';
import '../utils/view_state.dart';

class WalkingCourseProvider extends ChangeNotifier {
  final WalkingCourseRepository _repository;

  WalkingCourseProvider({WalkingCourseRepository? repository}) : _repository = repository ?? WalkingCourseRepository();

  ViewState _state = ViewState.idle;
  WalkingCourseModel? _result;
  String? _errorMessage;
  String? _region;

  ViewState get state => _state;
  WalkingCourseModel? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get region => _region;
  bool get isLoading => _state == ViewState.loading;

  Future<void> generate(String region) async {
    _region = region;
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _result = await _repository.generate(region: region, localTime: DateTime.now());
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  void reset() {
    _region = null;
    _result = null;
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
