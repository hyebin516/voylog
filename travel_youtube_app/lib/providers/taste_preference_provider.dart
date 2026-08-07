import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../repositories/taste_preference_repository.dart';
import '../utils/view_state.dart';

class TastePreferenceProvider extends ChangeNotifier {
  final TastePreferenceRepository _repository;

  TastePreferenceProvider({TastePreferenceRepository? repository})
      : _repository = repository ?? TastePreferenceRepository();

  ViewState _state = ViewState.idle;
  Set<String> _selectedTags = {};
  String? _errorMessage;
  bool _isSaving = false;

  ViewState get state => _state;
  Set<String> get selectedTags => _selectedTags;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;
  bool get isSaving => _isSaving;

  void toggleTag(String tag) {
    if (!_selectedTags.remove(tag)) _selectedTags.add(tag);
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final preferences = await _repository.getPreferences();
      _selectedTags = preferences.tags.toSet();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  Future<bool> save() async {
    if (_selectedTags.isEmpty) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final preferences = await _repository.setPreferences(_selectedTags.toList());
      _selectedTags = preferences.tags.toSet();
      _state = ViewState.success;
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      _state = ViewState.error;
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> reset() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.clearPreferences();
      _selectedTags = {};
      _state = ViewState.success;
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      _state = ViewState.error;
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
