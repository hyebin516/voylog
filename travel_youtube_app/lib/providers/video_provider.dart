import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/video_model.dart';
import '../repositories/video_repository.dart';
import '../utils/view_state.dart';

class VideoProvider extends ChangeNotifier {
  final VideoRepository _repository;

  VideoProvider({VideoRepository? repository}) : _repository = repository ?? VideoRepository();

  ViewState _state = ViewState.idle;
  VideoModel? _currentVideo;
  String? _errorMessage;

  ViewState get state => _state;
  VideoModel? get currentVideo => _currentVideo;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  Future<void> analyze(String youtubeUrl) async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentVideo = await _repository.analyze(youtubeUrl);
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  void reset() {
    _state = ViewState.idle;
    _currentVideo = null;
    _errorMessage = null;
    notifyListeners();
  }
}
