import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The Voylog "mountain peaks" logo mark: a rounded gradient square used
/// wherever the app's wordmark appears (splash, login, home).
class VoylogLogoMark extends StatelessWidget {
  const VoylogLogoMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentCyan, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(Icons.terrain_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}

/// The "Voylog" wordmark next to [VoylogLogoMark].
class VoylogWordmark extends StatelessWidget {
  const VoylogWordmark({super.key, this.fontSize = 24});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Voylog',
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppColors.ink),
    );
  }
}
