import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The Voylog "mountain peaks" glyph -- `M6 18c2-6 4-9 6-9s4 3 6 9` plus 3
/// dots at the two feet and the apex, traced from the design handoff's SVG
/// (same path used for the launcher icon, see scratchpad `make_app_icon.py`
/// / `assets/icon/app_icon.png`, and for the design's "여행" bottom-tab
/// icon). Used wherever that glyph appears instead of a generic Material
/// icon, so the logo mark, launcher icon, and "여행" tab icon all agree.
class MountainGlyphIcon extends StatelessWidget {
  const MountainGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MountainGlyphPainter(color: color),
    );
  }
}

class _MountainGlyphPainter extends CustomPainter {
  _MountainGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 24x24 viewBox scaled to fill the given box, centered.
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);

    final path = Path()
      ..moveTo(pt(6, 18).dx, pt(6, 18).dy)
      ..cubicTo(
        pt(8, 12).dx,
        pt(8, 12).dy,
        pt(10, 9).dx,
        pt(10, 9).dy,
        pt(12, 9).dx,
        pt(12, 9).dy,
      )
      ..cubicTo(
        pt(14, 9).dx,
        pt(14, 9).dy,
        pt(16, 12).dx,
        pt(16, 12).dy,
        pt(18, 18).dx,
        pt(18, 18).dy,
      );

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()..color = color;
    for (final p in [pt(6, 18), pt(12, 9), pt(18, 18)]) {
      canvas.drawCircle(p, 1.9 * scale, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MountainGlyphPainter oldDelegate) => oldDelegate.color != color;
}

/// The Voylog logo mark: a rounded gradient square with [MountainGlyphIcon]
/// in white, used wherever the app's wordmark appears (splash, login, home).
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
      child: Center(
        child: MountainGlyphIcon(size: size * 0.55, color: Colors.white),
      ),
    );
  }
}

/// The "Voylog" wordmark next to [VoylogLogoMark].
class VoylogWordmark extends StatelessWidget {
  const VoylogWordmark({super.key, this.fontSize = 24, this.color});

  final double fontSize;

  /// Defaults to the ink colour; the onboarding screen sets it white over
  /// the gradient.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Voylog',
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: color ?? AppColors.ink),
    );
  }
}
