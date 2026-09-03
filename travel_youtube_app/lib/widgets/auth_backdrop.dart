import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Soft gradient + blurred "blob" background used behind the splash/login/
/// signup/email-verify screens, matching the Voylog design prototype.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceTint, Colors.white],
          stops: [0.0, 0.55],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: -70, left: -60, child: _Blob(size: 220, color: Color(0xFFBFE6F7))),
          const Positioned(top: 40, right: -50, child: _Blob(size: 160, color: Color(0xFFDFF2FA))),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The pill-shaped back button used on every auth sub-screen (signup steps,
/// email verify) to return to the previous step.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.softShadow(opacity: 0.18, blurRadius: 12, offset: const Offset(0, 4)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.primary),
      ),
    );
  }
}
