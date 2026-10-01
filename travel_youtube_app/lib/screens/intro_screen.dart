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
                  child: Image.asset(
                    'assets/images/intro/video-sea-clean2.png',
                    fit: BoxFit.cover,
                  ),
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
                          for (final thumb in ['t1', 't2', 't3'])
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4 * scale),
                              child: Image.asset(
                                'assets/images/intro/$thumb.png',
                                width: 26 * scale,
                                height: 27 * scale,
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            iconAtEnd: true,
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
