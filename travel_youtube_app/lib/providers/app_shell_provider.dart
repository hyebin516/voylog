import 'package:flutter/foundation.dart';

/// Which bottom-nav tab [AppBottomNavShell] is showing.
///
/// Lives above the shell so a screen inside one tab can hand the user to
/// another: analyzing a URL on 홈 leaves the result on the 분석 tab and
/// returns 홈 to its normal state, ready for the next video.
class AppShellProvider extends ChangeNotifier {
  static const int homeTab = 0;
  static const int analysisTab = 1;
  static const int bookmarkTab = 2;
  static const int tripTab = 3;
  static const int myPageTab = 4;

  int _tabIndex = homeTab;

  int get tabIndex => _tabIndex;

  void goToTab(int index) {
    if (index == _tabIndex) return;
    _tabIndex = index;
    notifyListeners();
  }
}
