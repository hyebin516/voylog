import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'voylog_logo.dart';

/// The design's floating "내 여행" shortcut (rounded-square gradient button
/// with the mountain glyph) -- shared by the home screen and the bookmark
/// folders tab, both of which surface it in the same bottom-right spot.
class SavedRoutesFab extends StatelessWidget {
  const SavedRoutesFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '내 여행',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.accentCyan, AppColors.primaryStrong]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.primaryStrong.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 12))],
            ),
            child: const MountainGlyphIcon(size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
