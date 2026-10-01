import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';
import '../widgets/primary_button.dart';
import '../widgets/voylog_logo.dart';

/// The onboarding screen (handoff v2, `intro`): what the app is for, and one
/// way in.
///
/// Shown to a signed-out user before the login screen; a restored session
/// goes straight to home and never sees it.
///
/// Two typefaces from the handoff are not bundled: the wordmark's Poppins
/// (the shared [VoylogWordmark] stands in) and the Caveat handwriting on the
/// "From Vlog → To Travel Route" captions. Both are Google Fonts, and this
/// app loads fonts from `assets/fonts/` rather than the network, so they'd
/// need their `.ttf` adding the way Pretendard was.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.introGradient),
        child: Stack(
          children: [
            // The warm glow the handoff puts in the top-right corner.
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
            Align(alignment: Alignment.bottomCenter, child: _IntroSheet()),
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
                      child: const MountainGlyphIcon(size: 26, color: AppColors.primaryBrand),
                    ),
                    const SizedBox(width: 10),
                    // Poppins in the handoff; the shared wordmark stands in.
                    const VoylogWordmark(fontSize: 38, color: Colors.white),
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

/// The floating video and map cards over the landscape photo.
class _IntroArtwork extends StatelessWidget {
  const _IntroArtwork();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // The handoff lays the artwork out on a 393pt frame; everything below is
    // in those units and scaled to the real width.
    final scale = width / 393;

    return Positioned(
      left: 0,
      right: 0,
      top: 120 * scale,
      height: 400 * scale,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Landscape photo, fading in from the top so it meets the
            // gradient instead of cutting against it.
            Positioned(
              left: 0,
              right: 0,
              top: 216 * scale,
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
                ),
              ),
            ),
            Positioned(
              left: 36 * scale,
              top: 32 * scale,
              child: Transform.rotate(
                angle: -7 * math.pi / 180,
                child: _FloatingCard(
                  width: 162 * scale,
                  height: 104 * scale,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/intro/video-sea-clean2.png',
                        fit: BoxFit.cover,
                      ),
                      // Translucent play button over the thumbnail.
                      Center(
                        child: Container(
                          width: 30 * scale,
                          height: 22 * scale,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6 * scale),
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 16 * scale,
                            color: const Color(0xFF3AA6B0),
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
                      // Progress bar, 32% along.
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
                                child: ColoredBox(color: Colors.white.withValues(alpha: 0.95)),
                              ),
                              Expanded(
                                flex: 68,
                                child: ColoredBox(color: Colors.white.withValues(alpha: 0.35)),
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
            // YouTube badge, tucked against the video card's top-left.
            Positioned(
              left: 14 * scale,
              top: 14 * scale,
              child: Container(
                width: 36 * scale,
                height: 30 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8 * scale),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00323C).withValues(alpha: 0.18),
                      blurRadius: 10 * scale,
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
                  child: Icon(Icons.play_arrow_rounded, size: 13 * scale, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 208 * scale,
              top: 104 * scale,
              child: Transform.rotate(
                angle: 3.5 * math.pi / 180,
                child: _FloatingCard(
                  width: 160 * scale,
                  height: 112 * scale,
                  padding: 6 * scale,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 86,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5 * scale),
                          child: Image.asset(
                            'assets/images/intro/map-clean.png',
                            fit: BoxFit.cover,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      SizedBox(width: 6 * scale),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final (thumb, time) in const [
                            ('t1', '01:12'),
                            ('t2', '04:36'),
                            ('t3', '08:20'),
                          ])
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4 * scale),
                                  child: Image.asset(
                                    'assets/images/intro/$thumb.png',
                                    width: 26 * scale,
                                    height: 21 * scale,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                SizedBox(height: 1 * scale),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 7 * scale,
                                    height: 1,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF1A8F99),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Arrows and sparkles last, so they sit over the cards.
            Positioned.fill(
              child: CustomPaint(painter: _IntroFlourishPainter(scale)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The handoff's hand-drawn flourishes: three curved arrows tying the video
/// card to the map card, and two clusters of sparkle strokes.
class _IntroFlourishPainter extends CustomPainter {
  const _IntroFlourishPainter(this.scale);

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    Offset pt(double x, double y) => Offset(x * scale, y * scale);

    // Arrow from the "From Vlog" caption down to the video card.
    _arrow(canvas, stroke, pt(252, 22), pt(286, 44), pt(300, 74), scale);
    // Arrow curving from the video card across to the map card.
    _arrow(canvas, stroke, pt(206, 96), pt(236, 76), pt(268, 86), scale);
    // Arrow from the "To Travel Route" caption up to the map card.
    _arrow(canvas, stroke, pt(104, 190), pt(140, 176), pt(176, 158), scale);

    _sparkle(canvas, stroke, pt(228, 18), 7);
    _sparkle(canvas, stroke, pt(330, 118), 6);
  }

  /// A quadratic curve from [from] through [control] to [to], with a two-
  /// stroke head at the end.
  void _arrow(Canvas canvas, Paint paint, Offset from, Offset control, Offset to, double scale) {
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy),
      paint,
    );

    // Head angled along the curve's final direction.
    final dx = to.dx - control.dx;
    final dy = to.dy - control.dy;
    final angle = math.atan2(dy, dx);
    const spread = 0.5;
    final headLength = 7 * scale;
    for (final offset in [spread, -spread]) {
      canvas.drawLine(
        to,
        Offset(
          to.dx - headLength * math.cos(angle + offset),
          to.dy - headLength * math.sin(angle + offset),
        ),
        paint,
      );
    }
  }

  /// A four-pointed twinkle: one long axis, one short.
  void _sparkle(Canvas canvas, Paint paint, Offset center, double radius) {
    final r = radius * scale;
    canvas.drawLine(center.translate(0, -r), center.translate(0, r), paint);
    canvas.drawLine(center.translate(-r * 0.42, 0), center.translate(r * 0.42, 0), paint);
    // A smaller companion, offset, so the pair reads as a twinkle rather
    // than a plus sign.
    final small = center.translate(r * 1.5, r * 1.1);
    canvas.drawLine(small.translate(0, -r * 0.5), small.translate(0, r * 0.5), paint);
    canvas.drawLine(small.translate(-r * 0.22, 0), small.translate(r * 0.22, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _IntroFlourishPainter oldDelegate) => oldDelegate.scale != scale;
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.width,
    required this.height,
    required this.child,
    this.padding = 0,
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
      padding: EdgeInsets.all(padding == 0 ? 5 : padding),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '브이로그가\n'),
                // The handoff underlines this by hand; a solid rule would
                // read as a link, so it stays colour-only until the
                // hand-drawn stroke is traced.
                TextSpan(
                  text: '여행 일정',
                  style: TextStyle(color: Color(0xFF149AA3)),
                ),
                TextSpan(text: '이 되는 순간'),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -1,
              color: AppColors.ink,
            ),
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
            // The handoff puts the arrow at the right edge with the label
            // centred, not in front of it.
            iconAtEnd: true,
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
