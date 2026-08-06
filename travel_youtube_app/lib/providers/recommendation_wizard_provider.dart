import 'package:flutter/foundation.dart';

/// Holds the in-progress selections across the region -> theme -> duration
/// wizard screens. The actual video search itself (and its loading/result
/// state) lives on [VideoProvider.searchByRecommendation] — this provider is
/// only the wizard's own step state.
class RecommendationWizardProvider extends ChangeNotifier {
  final Set<String> _selectedRegions = {};
  final Set<String> _selectedThemes = {};
  String? _selectedDuration;

  Set<String> get selectedRegions => _selectedRegions;
  Set<String> get selectedThemes => _selectedThemes;
  String? get selectedDuration => _selectedDuration;

  bool get canProceedFromRegions => _selectedRegions.isNotEmpty;
  bool get canProceedFromThemes => _selectedThemes.isNotEmpty;
  bool get canSearch => _selectedRegions.isNotEmpty && _selectedThemes.isNotEmpty && _selectedDuration != null;

  void toggleRegion(String region) {
    if (!_selectedRegions.remove(region)) _selectedRegions.add(region);
    notifyListeners();
  }

  void toggleTheme(String theme) {
    if (!_selectedThemes.remove(theme)) _selectedThemes.add(theme);
    notifyListeners();
  }

  void selectDuration(String duration) {
    _selectedDuration = duration;
    notifyListeners();
  }

  void reset() {
    _selectedRegions.clear();
    _selectedThemes.clear();
    _selectedDuration = null;
    notifyListeners();
  }
}
