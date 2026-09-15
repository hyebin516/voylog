import 'package:flutter/material.dart';

/// A rounded-rect container with a dashed border, matching the design
/// handoff's `border: 2px dashed #bfe0f2` treatment (used for "장소
/// 추가하기"/"내 동선 추천하기"/"날짜 추가" style affordances) -- Flutter's
/// [Border] only draws solid lines, so this paints the dashes itself.
class DashedBorderContainer extends StatelessWidget {
  const DashedBorderContainer({
    super.key,
    required this.child,
    this.color = const Color(0xFFBFE0F2),
    this.backgroundColor,
    this.strokeWidth = 2,
    this.borderRadius = 18,
    this.dashLength = 6,
    this.gapLength = 4,
    this.padding,
  });

  final Widget child;
  final Color color;
  final Color? backgroundColor;
  final double strokeWidth;
  final double borderRadius;
  final double dashLength;
  final double gapLength;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        color: color,
        strokeWidth: strokeWidth,
        radius: borderRadius,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          color: backgroundColor,
          padding: padding ?? const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth || oldDelegate.radius != radius;
}
