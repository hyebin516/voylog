import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'voylog_logo.dart';

/// The design's floating "내 여행" shortcut (rounded-square gradient button
/// with the mountain glyph) -- shared by the home screen and the bookmark
/// folders tab, both of which surface it in the same bottom-right spot.
///
/// It steps aside while the keyboard is open: the Scaffold lifts its FAB
/// above the keyboard, parking it on top of whatever field is being typed
/// into -- it covered the home hashtag field's search button. A shortcut to
/// another screen is no use mid-typing.
///
/// The keyboard is read from the window rather than from MediaQuery, and
/// watched via [WidgetsBindingObserver]: every Scaffold between the window
/// and this button strips the bottom inset out of its body's MediaQuery
/// (the tab shell is one, the screen's own Scaffold another), so by the time
/// it gets here the inset always reads zero.
class SavedRoutesFab extends StatefulWidget {
  const SavedRoutesFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<SavedRoutesFab> createState() => _SavedRoutesFabState();
}

class _SavedRoutesFabState extends State<SavedRoutesFab> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (View.of(context).viewInsets.bottom > 0) return const SizedBox.shrink();

    return Tooltip(
      message: '내 여행',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.fabShadow(),
            ),
            child: const MountainGlyphIcon(size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
