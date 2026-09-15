import 'package:flutter/material.dart';

/// Exact line-art icons traced from the design handoff's bottom-tab SVGs
/// (`voylog-prototype-source.dc.html`, `isHome`/`isBookmarkFolders` blocks),
/// instead of visually-approximate Material icons. Each takes a 24x24
/// viewBox scaled to fill the given [size], stroked at the same relative
/// width the SVGs use (~1.8-2 / 24).
class HomeGlyphIcon extends StatelessWidget {
  const HomeGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _HomePainter(color));
}

class _HomePainter extends CustomPainter {
  _HomePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roof = Path()
      ..moveTo(pt(4, 11.5).dx, pt(4, 11.5).dy)
      ..lineTo(pt(12, 5).dx, pt(12, 5).dy)
      ..lineTo(pt(20, 11.5).dx, pt(20, 11.5).dy);
    canvas.drawPath(roof, paint);

    final body = Path()
      ..moveTo(pt(6, 10).dx, pt(6, 10).dy)
      ..lineTo(pt(6, 18).dx, pt(6, 18).dy)
      ..arcToPoint(pt(7, 19), radius: Radius.circular(1 * scale))
      ..lineTo(pt(17, 19).dx, pt(17, 19).dy)
      ..arcToPoint(pt(18, 18), radius: Radius.circular(1 * scale), clockwise: false)
      ..lineTo(pt(18, 10).dx, pt(18, 10).dy);
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant _HomePainter oldDelegate) => oldDelegate.color != color;
}

/// The design's "분석" tab icon: three ascending, rounded-rect bars (a bar
/// chart), not the sparkle/magic-wand or generic Material bar_chart icon.
class AnalysisGlyphIcon extends StatelessWidget {
  const AnalysisGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _AnalysisPainter(color));
}

class _AnalysisPainter extends CustomPainter {
  _AnalysisPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale;

    void bar(double x, double y, double w, double h) {
      final rect = Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(2 * scale)), paint);
    }

    bar(4, 12, 4, 8);
    bar(10, 7, 4, 13);
    bar(16, 3, 4, 17);
  }

  @override
  bool shouldRepaint(covariant _AnalysisPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's bookmark-ribbon icon (used for the "북마크" tab).
class BookmarkGlyphIcon extends StatelessWidget {
  const BookmarkGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _BookmarkPainter(color));
}

class _BookmarkPainter extends CustomPainter {
  _BookmarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(pt(7, 4).dx, pt(7, 4).dy)
      ..lineTo(pt(17, 4).dx, pt(17, 4).dy)
      ..arcToPoint(pt(18, 5), radius: Radius.circular(1 * scale), clockwise: true)
      ..lineTo(pt(18, 20).dx, pt(18, 20).dy)
      ..lineTo(pt(12, 16).dx, pt(12, 16).dy)
      ..lineTo(pt(6, 20).dx, pt(6, 20).dy)
      ..lineTo(pt(6, 5).dx, pt(6, 5).dy)
      ..arcToPoint(pt(7, 4), radius: Radius.circular(1 * scale), clockwise: true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BookmarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's simple person-silhouette icon (used for "내 페이지").
class PersonGlyphIcon extends StatelessWidget {
  const PersonGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _PersonPainter(color));
}

class _PersonPainter extends CustomPainter {
  _PersonPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(pt(12, 8), 3.4 * scale, paint);

    final shoulders = Path()..moveTo(pt(5, 20).dx, pt(5, 20).dy);
    shoulders.cubicTo(
      pt(6.2, 16).dx,
      pt(6.2, 16).dy,
      pt(9, 14).dx,
      pt(9, 14).dy,
      pt(12, 14).dx,
      pt(12, 14).dy,
    );
    shoulders.cubicTo(
      pt(15, 14).dx,
      pt(15, 14).dy,
      pt(17.8, 16).dx,
      pt(17.8, 16).dy,
      pt(19, 20).dx,
      pt(19, 20).dy,
    );
    canvas.drawPath(shoulders, paint);
  }

  @override
  bool shouldRepaint(covariant _PersonPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's map-pin icon (used for the home screen's "내 주변 추천"
/// quick-entry card) -- a hollow teardrop outline with a small ring at its
/// center, not Material's solid/filled pin.
class LocationPinGlyphIcon extends StatelessWidget {
  const LocationPinGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _LocationPinPainter(color));
}

class _LocationPinPainter extends CustomPainter {
  _LocationPinPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pt(12, 21).dx, pt(12, 21).dy);
    path.cubicTo(pt(12, 21).dx, pt(12, 21).dy, pt(5, 14.8).dx, pt(5, 14.8).dy, pt(5, 10).dx, pt(5, 10).dy);
    path.arcToPoint(pt(19, 10), radius: Radius.circular(7 * scale), clockwise: true);
    path.cubicTo(pt(19, 14.8).dx, pt(19, 14.8).dy, pt(12, 21).dx, pt(12, 21).dy, pt(12, 21).dx, pt(12, 21).dy);
    canvas.drawPath(path, paint);

    canvas.drawCircle(pt(12, 10), 2.4 * scale, paint);
  }

  @override
  bool shouldRepaint(covariant _LocationPinPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's place-card "지도 보기" pin icon -- a narrower teardrop than
/// [LocationPinGlyphIcon] (that one belongs to a different card, its own
/// traced path), not Material's folded-map glyph.
class MapPinGlyphIcon extends StatelessWidget {
  const MapPinGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _MapPinPainter(color));
}

class _MapPinPainter extends CustomPainter {
  _MapPinPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pt(12, 21).dx, pt(12, 21).dy);
    path.cubicTo(pt(12, 21).dx, pt(12, 21).dy, pt(6, 15.8).dx, pt(6, 15.8).dy, pt(6, 11.5).dx, pt(6, 11.5).dy);
    path.arcToPoint(pt(18, 11.5), radius: Radius.circular(6 * scale), clockwise: true);
    path.cubicTo(pt(18, 15.8).dx, pt(18, 15.8).dy, pt(12, 21).dx, pt(12, 21).dy, pt(12, 21).dx, pt(12, 21).dy);
    canvas.drawPath(path, paint);

    canvas.drawCircle(pt(12, 11.2), 2 * scale, paint);
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's walking-figure icon (head dot + zigzag body/legs), used
/// for the "뚜벅이 코스" quick-entry card, not Material's filled pictogram.
class WalkingGlyphIcon extends StatelessWidget {
  const WalkingGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _WalkingPainter(color));
}

class _WalkingPainter extends CustomPainter {
  _WalkingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(pt(13, 4), 1.6 * scale, paint);

    final body = Path()
      ..moveTo(pt(11, 21).dx, pt(11, 21).dy)
      ..lineTo(pt(12.5, 15.5).dx, pt(12.5, 15.5).dy)
      ..lineTo(pt(10, 13.5).dx, pt(10, 13.5).dy)
      ..lineTo(pt(11, 8.5).dx, pt(11, 8.5).dy)
      ..lineTo(pt(14.5, 11).dx, pt(14.5, 11).dy)
      ..lineTo(pt(17, 11.5).dx, pt(17, 11.5).dy);
    canvas.drawPath(body, paint);

    final leg = Path()
      ..moveTo(pt(8.5, 13.5).dx, pt(8.5, 13.5).dy)
      ..lineTo(pt(7, 21).dx, pt(7, 21).dy);
    canvas.drawPath(leg, paint);
  }

  @override
  bool shouldRepaint(covariant _WalkingPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's link icon (used in the URL-paste input on Home/분석), not
/// Material's `Icons.link_rounded` chain glyph -- a diagonal stroke plus
/// two open hook shapes at opposite corners.
class LinkGlyphIcon extends StatelessWidget {
  const LinkGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _LinkPainter(color));
}

class _LinkPainter extends CustomPainter {
  _LinkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(pt(9, 15), pt(15, 9), paint);

    final hook1 = Path()
      ..moveTo(pt(8, 13).dx, pt(8, 13).dy)
      ..lineTo(pt(6.5, 14.5).dx, pt(6.5, 14.5).dy)
      ..arcToPoint(pt(11.5, 19.5), radius: Radius.circular(3.5 * scale), clockwise: false)
      ..lineTo(pt(13, 18).dx, pt(13, 18).dy);
    canvas.drawPath(hook1, paint);

    final hook2 = Path()
      ..moveTo(pt(16, 11).dx, pt(16, 11).dy)
      ..lineTo(pt(17.5, 9.5).dx, pt(17.5, 9.5).dy)
      ..arcToPoint(pt(12.5, 4.5), radius: Radius.circular(3.5 * scale), clockwise: false)
      ..lineTo(pt(11, 6).dx, pt(11, 6).dy);
    canvas.drawPath(hook2, paint);
  }

  @override
  bool shouldRepaint(covariant _LinkPainter oldDelegate) => oldDelegate.color != color;
}

/// The design's AI-sparkle icon ("AI 동선 생성하기" button) -- 8 radiating
/// line segments around a filled center dot, not Material's 4-point
/// `Icons.auto_awesome` star.
class SparkleGlyphIcon extends StatelessWidget {
  const SparkleGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _SparklePainter(color));
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(pt(12, 3), pt(12, 6), paint);
    canvas.drawLine(pt(12, 18), pt(12, 21), paint);
    canvas.drawLine(pt(3, 12), pt(6, 12), paint);
    canvas.drawLine(pt(18, 12), pt(21, 12), paint);
    canvas.drawLine(pt(5.6, 5.6), pt(7.7, 7.7), paint);
    canvas.drawLine(pt(16.3, 16.3), pt(18.4, 18.4), paint);
    canvas.drawLine(pt(5.6, 18.4), pt(7.7, 16.3), paint);
    canvas.drawLine(pt(16.3, 7.7), pt(18.4, 5.6), paint);

    canvas.drawCircle(pt(12, 12), 3 * scale, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// The design's folder icon (rounded rect with a tab), used in the "북마크에
/// 저장" sheet's folder rows -- not Material's `Icons.folder_outlined`.
class FolderGlyphIcon extends StatelessWidget {
  const FolderGlyphIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size), painter: _FolderPainter(color));
}

class _FolderPainter extends CustomPainter {
  _FolderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset pt(double x, double y) => Offset(x * scale, y * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pt(4, 8).dx, pt(4, 8).dy);
    path.arcToPoint(pt(6, 6), radius: Radius.circular(2 * scale), clockwise: true);
    path.lineTo(pt(10, 6).dx, pt(10, 6).dy);
    path.lineTo(pt(12, 8).dx, pt(12, 8).dy);
    path.lineTo(pt(18, 8).dx, pt(18, 8).dy);
    path.arcToPoint(pt(20, 10), radius: Radius.circular(2 * scale), clockwise: true);
    path.lineTo(pt(20, 16).dx, pt(20, 16).dy);
    path.arcToPoint(pt(18, 18), radius: Radius.circular(2 * scale), clockwise: true);
    path.lineTo(pt(6, 18).dx, pt(6, 18).dy);
    path.arcToPoint(pt(4, 16), radius: Radius.circular(2 * scale), clockwise: true);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) => oldDelegate.color != color;
}
