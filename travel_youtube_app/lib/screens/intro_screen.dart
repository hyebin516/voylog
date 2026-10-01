import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';
import '../widgets/primary_button.dart';

/// The onboarding screen (handoff v2, `intro`): what the app is for, and one
/// way in.
///
/// Shown to a signed-out user before the login screen; a restored session
/// goes straight to home and never sees it.
///
/// Everything here is traced from `Voylog App v2.dc.html` rather than from
/// the README's summary -- the positions, rotations and SVG paths only exist
/// in the markup. The handoff's frame is 393pt wide and the artwork is
/// positioned absolutely within it, so the layout below works in those units
/// and scales them to the real width.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.introGradient),
        child: Stack(
          children: [
            // The glow in the top-right corner.
            Positioned(
              top: -60,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF78DCD2).withValues(alpha: 0.45),
                      const Color(0xFF78DCD2).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            const _IntroArtwork(),
            const Align(alignment: Alignment.bottomCenter, child: _IntroSheet()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF003C46).withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const SizedBox(
                        width: 30,
                        height: 27,
                        child: CustomPaint(painter: _RouteGlyphPainter()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Voylog',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 38,
                        height: 1,
                        letterSpacing: -0.5,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF003C46).withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating cards, the landscape photo, the handwriting and the
/// flourishes. The group's own `transform: scale(.86)` is applied here.
class _IntroArtwork extends StatelessWidget {
  const _IntroArtwork();

  /// Where this box starts in the handoff's frame, so the markup's absolute
  /// `top:` values can be used directly minus this.
  static const double _groupTop = 120;
  static const double _groupHeight = 400;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / 393;

    return Positioned(
      left: 0,
      right: 0,
      top: _groupTop * scale,
      height: _groupHeight * scale,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // top:336 height:176, masked transparent->opaque over the first
            // 34%, image anchored at "center 30%". A sibling of the scaled
            // group in the markup, not a child of it -- so it keeps the full
            // width while the cards shrink.
            Positioned(
              left: 0,
              right: 0,
              top: (336 - _groupTop) * scale,
              height: 176 * scale,
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white],
                  stops: [0.0, 0.34],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/images/intro/landscape.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.4),
                ),
              ),
            ),
            // `transform: scale(.86); transform-origin: 50% 240px`, where
            // 240 is measured from the top of the frame.
            Positioned.fill(
              child: Transform.scale(
                scale: 0.86,
                alignment: Alignment(0, ((240 - _groupTop) / _groupHeight) * 2 - 1),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Video card: left:36 top:152, 162x104, rotate -7deg.
                    Positioned(
                      left: 36 * scale,
                      top: (152 - _groupTop) * scale,
                      child: Transform.rotate(
                        angle: -7 * math.pi / 180,
                        child: _FloatingCard(
                          width: 162 * scale,
                          height: 104 * scale,
                          padding: 5 * scale,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/intro/video-sea-clean2.png',
                                fit: BoxFit.cover,
                              ),
                              Center(
                                child: Container(
                                  width: 30 * scale,
                                  height: 22 * scale,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6 * scale),
                                  ),
                                  child: SizedBox(
                                    width: 8 * scale,
                                    height: 9 * scale,
                                    child: const CustomPaint(
                                      painter: _PlayTrianglePainter(Color(0xFF3AA6B0)),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 5 * scale,
                                bottom: 7 * scale,
                                child: Text(
                                  '12:34',
                                  style: TextStyle(
                                    fontSize: 8 * scale,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: SizedBox(
                                  height: 2 * scale,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 32,
                                        child: ColoredBox(
                                          color: Colors.white.withValues(alpha: 0.95),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 68,
                                        child: ColoredBox(
                                          color: Colors.white.withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // YouTube badge: left:26 top:146, 36x30 white box around
                    // a 26x19 red chip, tilted -7deg like the card it leans
                    // on. Sitting it further up and left ran it into the
                    // sparkle.
                    Positioned(
                      left: 26 * scale,
                      top: (146 - _groupTop) * scale,
                      child: Transform.rotate(
                        angle: -7 * math.pi / 180,
                        child: Container(
                          width: 36 * scale,
                          height: 30 * scale,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8 * scale,
                                offset: Offset(0, 3 * scale),
                              ),
                            ],
                          ),
                          child: Container(
                            width: 26 * scale,
                            height: 19 * scale,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(5 * scale),
                            ),
                            child: SizedBox(
                              width: 7 * scale,
                              height: 8 * scale,
                              child: const CustomPaint(painter: _PlayTrianglePainter(Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Map card: left:208 top:224, 160x112, rotate 3.5deg.
                    Positioned(
                      left: 208 * scale,
                      top: (224 - _groupTop) * scale,
                      child: Transform.rotate(
                        angle: 3.5 * math.pi / 180,
                        child: _FloatingCard(
                          width: 160 * scale,
                          height: 112 * scale,
                          padding: 6 * scale,
                          child: Row(
                            children: [
                              // The map is a fixed 86 wide, not a share of
                              // the row -- giving it a flex squeezed the
                              // column beside it and cropped the map.
                              SizedBox(
                                width: 86 * scale,
                                height: double.infinity,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6 * scale),
                                  child: Image.asset(
                                    'assets/images/intro/map-clean.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6 * scale),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 1 * scale),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final (thumb, time) in const [
                                        ('t1', '01:12'),
                                        ('t2', '04:36'),
                                        ('t3', '08:20'),
                                      ])
                                        // Thumbnail and time sit side by
                                        // side with a 5 gap, not stacked.
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4 * scale),
                                              child: Image.asset(
                                                'assets/images/intro/$thumb.png',
                                                width: 26 * scale,
                                                height: 27 * scale,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            SizedBox(width: 5 * scale),
                                            // Flexible, because the time's
                                            // width depends on the font the
                                            // platform resolves and a few
                                            // pixels over blows the card.
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  time,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 7.5 * scale,
                                                    height: 1,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF1A8F99),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // left:226 top:132, rotate -12deg, Caveat 500 21px/.95, with
                    // "Vlog" indented 20px under "From".
                    Positioned(
                      left: 226 * scale,
                      top: (132 - _groupTop) * scale,
                      child: Transform.rotate(
                        angle: -12 * math.pi / 180,
                        alignment: Alignment.topLeft,
                        child: _Handwriting(
                          fontSize: 21 * scale,
                          lineHeight: 0.95,
                          lines: [(0.0, 'From'), (20.0 * scale, 'Vlog')],
                        ),
                      ),
                    ),
                    // left:90 top:286, rotate -11deg, Caveat 500 19px/1.
                    Positioned(
                      left: 90 * scale,
                      top: (286 - _groupTop) * scale,
                      child: Transform.rotate(
                        angle: -11 * math.pi / 180,
                        alignment: Alignment.topLeft,
                        child: _Handwriting(
                          fontSize: 19 * scale,
                          lineHeight: 1,
                          lines: const [(0.0, 'To'), (0.0, 'Travel Route')],
                        ),
                      ),
                    ),
                    Positioned.fill(child: CustomPaint(painter: _IntroFlourishPainter(scale))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Caveat captions. Written line by line because the handoff indents
/// "Vlog" under "From" with its own padding.
class _Handwriting extends StatelessWidget {
  const _Handwriting({required this.lines, required this.fontSize, required this.lineHeight});

  /// `(leftPadding, text)` per line.
  final List<(double, String)> lines;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (indent, text) in lines)
          Padding(
            padding: EdgeInsets.only(left: indent),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Caveat',
                fontWeight: FontWeight.w500,
                fontSize: fontSize,
                height: lineHeight,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.width,
    required this.height,
    required this.child,
    required this.padding,
  });

  final double width;
  final double height;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00323C).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
    );
  }
}

/// The bottom sheet: headline, one line of explanation, and the way in.
class _IntroSheet extends StatelessWidget {
  const _IntroSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfacePage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(30, 36, 30, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('브이로그가', textAlign: TextAlign.center, style: _headlineStyle),
          // "여행 일정" carries a hand-drawn underline that runs a little
          // past the words, so it gets its own stack rather than sitting
          // inline with the rest of the line.
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '여행 일정',
                      style: TextStyle(color: Color(0xFF149AA3)),
                    ),
                    TextSpan(text: '이 되는 순간'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: _headlineStyle,
              ),
              Positioned(
                left: 0,
                // The underline belongs to "여행 일정" alone, which is the
                // first 4 of the line's 10 characters.
                right: null,
                width: 150,
                bottom: -4,
                height: 10,
                child: CustomPaint(painter: _HeadlineUnderlinePainter()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '유튜브 영상 링크 하나만 넣어보세요.\nAI가 영상 속 장소를 찾아 동선으로 정리해드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.6,
              letterSpacing: -0.3,
              color: Color(0xFF3A4A50),
            ),
          ),
          const SizedBox(height: 30),
          PrimaryButton(
            key: const Key('introStartButton'),
            label: '동선 만들기 시작',
            icon: Icons.arrow_forward_rounded,
            // The handoff floats the arrow 22px from the right edge with
            // the label centred.
            iconAtEnd: true,
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          ),
        ],
      ),
    );
  }
}

const TextStyle _headlineStyle = TextStyle(
  fontSize: 33,
  fontWeight: FontWeight.w800,
  height: 1.3,
  letterSpacing: -1,
  color: AppColors.ink,
);

/// The headline's hand-drawn underline: `M2 7 C50 2 100 2 148 5`, 2.5px
/// `#1a9aa3`, on a 150x10 box.
class _HeadlineUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 150;
    final sy = size.height / 10;
    Offset pt(double x, double y) => Offset(x * sx, y * sy);

    canvas.drawPath(
      Path()
        ..moveTo(pt(2, 7).dx, pt(2, 7).dy)
        ..cubicTo(
          pt(50, 2).dx,
          pt(50, 2).dy,
          pt(100, 2).dx,
          pt(100, 2).dy,
          pt(148, 5).dx,
          pt(148, 5).dy,
        ),
      Paint()
        ..color = const Color(0xFF1A9AA3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HeadlineUnderlinePainter oldDelegate) => false;
}

/// A play triangle: `M0 0 L<w> <h/2> L0 <h> Z`.
class _PlayTrianglePainter extends CustomPainter {
  const _PlayTrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayTrianglePainter oldDelegate) => oldDelegate.color != color;
}

/// The prototype's flourishes, traced path for path.
///
/// Each group below is one `<svg>` from the illustration: its absolute
/// position (minus the group's 120 top offset), its stroke width, and the
/// `d` attribute's points. Two are sparkle bursts -- three separate strokes,
/// not a star -- and three are arrows drawn with an explicit two-stroke head.
class _IntroFlourishPainter extends CustomPainter {
  const _IntroFlourishPainter(this.scale);

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    // Sparkle, left:16 top:130 -- "M4 22 L1 17  M11 16 L8 4  M20 14 L23 6"
    _strokes(canvas, 16, 10, 2.2, const [
      [4, 22, 1, 17],
      [11, 16, 8, 4],
      [20, 14, 23, 6],
    ]);
    // Arrow, left:300 top:156 -- "M14 2 C28 6 28 22 8 34  M8 34 L9 25  M8 34 L17 33"
    _curve(canvas, 300, 36, 2, const [14, 2, 28, 6, 28, 22, 8, 34]);
    _strokes(canvas, 300, 36, 2, const [
      [8, 34, 9, 25],
      [8, 34, 17, 33],
    ]);
    // Arrow, left:230 top:202 -- "M1 1 L13 11  M13 11 L13 4  M13 11 L6 11"
    _strokes(canvas, 230, 82, 1.8, const [
      [1, 1, 13, 11],
      [13, 11, 13, 4],
      [13, 11, 6, 11],
    ]);
    // Sparkle, left:356 top:212 -- "M4 12 L3 2  M13 12 L16 3  M20 20 L28 15"
    _strokes(canvas, 356, 92, 2.2, const [
      [4, 12, 3, 2],
      [13, 12, 16, 3],
      [20, 20, 28, 15],
    ]);
    // Arrow, left:166 top:260 -- "M2 2 C8 16 22 24 38 24  M38 24 L31 18  M38 24 L31 29"
    _curve(canvas, 166, 140, 2, const [2, 2, 8, 16, 22, 24, 38, 24]);
    _strokes(canvas, 166, 140, 2, const [
      [38, 24, 31, 18],
      [38, 24, 31, 29],
    ]);
  }

  Paint _paint(double width) => Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * scale
    ..strokeCap = StrokeCap.round;

  void _strokes(Canvas canvas, double ox, double oy, double width, List<List<int>> segments) {
    final paint = _paint(width);
    for (final s in segments) {
      canvas.drawLine(
        Offset((ox + s[0]) * scale, (oy + s[1]) * scale),
        Offset((ox + s[2]) * scale, (oy + s[3]) * scale),
        paint,
      );
    }
  }

  void _curve(Canvas canvas, double ox, double oy, double width, List<int> c) {
    Offset pt(int x, int y) => Offset((ox + x) * scale, (oy + y) * scale);
    canvas.drawPath(
      Path()
        ..moveTo(pt(c[0], c[1]).dx, pt(c[0], c[1]).dy)
        ..cubicTo(
          pt(c[2], c[3]).dx,
          pt(c[2], c[3]).dy,
          pt(c[4], c[5]).dx,
          pt(c[4], c[5]).dy,
          pt(c[6], c[7]).dx,
          pt(c[6], c[7]).dy,
        ),
      _paint(width),
    );
  }

  @override
  bool shouldRepaint(covariant _IntroFlourishPainter oldDelegate) => oldDelegate.scale != scale;
}

/// The logo box's route glyph: three dots joined by a curve, traced from
/// `M6 18c2-6 4-9 6-9s4 3 6 9` with r=2 dots at (6,18), (12,9) and (18,18)
/// on the prototype's `2.5 4.5 19 17` viewBox.
class _RouteGlyphPainter extends CustomPainter {
  const _RouteGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 19;
    Offset pt(double x, double y) => Offset((x - 2.5) * scale, (y - 4.5) * scale);

    // c2-6 4-9 6-9, then s4 3 6 9 (the smooth form mirrors the previous
    // control point).
    canvas.drawPath(
      Path()
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
        ),
      Paint()
        ..color = AppColors.primaryBrand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = AppColors.primaryBrand;
    for (final c in const [
      [6.0, 18.0],
      [12.0, 9.0],
      [18.0, 18.0],
    ]) {
      canvas.drawCircle(pt(c[0], c[1]), 2 * scale, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteGlyphPainter oldDelegate) => false;
}
