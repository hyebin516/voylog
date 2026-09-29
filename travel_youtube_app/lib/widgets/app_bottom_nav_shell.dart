import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/app_shell_provider.dart';
import '../screens/analysis_tab_screen.dart';
import '../screens/bookmark_folder_list_screen.dart';
import '../screens/home_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/trip_list_screen.dart';
import 'nav_icons.dart';
import 'voylog_logo.dart';

/// Persistent bottom-tab shell for the 5 root destinations the design
/// handoff specifies (홈/분석/북마크/여행/내 페이지). Every other screen in
/// the app is still reached by pushing on top of this shell -- only these
/// five live inside the [IndexedStack] so each tab keeps its own state
/// when switching away and back.
class AppBottomNavShell extends StatelessWidget {
  const AppBottomNavShell({super.key});

  static const _tabs = [
    _TabSpec(label: '홈', glyph: _Glyph.home),
    _TabSpec(label: '분석', glyph: _Glyph.analysis),
    _TabSpec(label: '북마크', glyph: _Glyph.bookmark),
    _TabSpec(label: '여행', glyph: _Glyph.mountain),
    _TabSpec(label: '내 페이지', glyph: _Glyph.person),
  ];

  static const _pages = [
    HomeScreen(),
    AnalysisTabScreen(),
    BookmarkFolderListScreen(isTabRoot: true),
    TripListScreen(isTabRoot: true),
    MyPageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // The selected tab lives in a provider, not in this widget's state, so
    // a screen inside a tab can move the user to another one (홈's analyze
    // hands the result to 분석).
    final shell = context.watch<AppShellProvider>();

    return Scaffold(
      body: IndexedStack(index: shell.tabIndex, children: _pages),
      bottomNavigationBar: _BottomBar(
        currentIndex: shell.tabIndex,
        tabs: _tabs,
        onTap: shell.goToTab,
      ),
    );
  }
}

enum _Glyph { home, analysis, bookmark, mountain, person }

Widget _glyphFor(_Glyph glyph, {required double size, required Color color}) {
  switch (glyph) {
    case _Glyph.home:
      return HomeGlyphIcon(size: size, color: color);
    case _Glyph.analysis:
      return AnalysisGlyphIcon(size: size, color: color);
    case _Glyph.bookmark:
      return BookmarkGlyphIcon(size: size, color: color);
    case _Glyph.mountain:
      return MountainGlyphIcon(size: size, color: color);
    case _Glyph.person:
      return PersonGlyphIcon(size: size, color: color);
  }
}

class _TabSpec {
  const _TabSpec({required this.label, required this.glyph});

  final String label;
  final _Glyph glyph;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.tabs, required this.onTap});

  final int currentIndex;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 9, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        boxShadow: AppColors.tabBarShadow(),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: InkWell(
                  key: Key('bottomTab_${tabs[i].label}'),
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == currentIndex ? AppColors.surfaceTint3 : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: _glyphFor(
                            tabs[i].glyph,
                            size: 24,
                            color: i == currentIndex ? AppColors.primary : AppColors.textMuted2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            // The active label is bolder as well as darker.
                            fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w600,
                            color: i == currentIndex ? AppColors.primary : AppColors.textMuted2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
