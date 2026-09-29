import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The background behind the splash/login/signup/email-verify screens.
///
/// v1 layered a blue gradient and two decorative circles ("blobs") here.
/// v2 removes the blobs everywhere and makes every screen a flat
/// `surface-page`, so this is now just that colour -- kept as a widget so the
/// ten screens using it stay one edit away from any future change.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.surfacePage, child: child);
  }
}

/// The pill-shaped back button used on every auth sub-screen (signup steps,
/// email verify) to return to the previous step.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // v2: 36x36, radius 12, white, `sh-back-btn`, 17px chevron in
    // `text-secondary`.
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: AppColors.backButtonShadow(),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary),
      ),
    );
  }
}
