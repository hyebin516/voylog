import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/video_provider.dart';

/// How long the first pass usually takes. Measured at 15-27s for a typical
/// video (see CLAUDE.md's "장소 추출 모델"), so the handoff's 20 is a fair
/// middle. Nothing reports real progress -- the server answers once, at the
/// end -- so this screen is paced, not measured.
const Duration _expectedDuration = Duration(seconds: 20);

const List<String> _steps = [
  '자막 불러오기',
  '장소 후보 추출',
  '지도 좌표 매칭',
  '결과 정리',
];

/// The wait after 분석하기 on the home screen (FR-01).
///
/// Covers the **first pass only**: the places come back, this closes, and the
/// background enrichment (OCR, 2-3 minutes) carries on behind the results as
/// it always has. Holding the user here for the enrichment would be a change
/// to the flow, not to its looks.
///
/// Closes itself when the analysis leaves its loading state, whether it
/// succeeded or failed -- the home screen shows the error in place.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  static const Duration _tick = Duration(milliseconds: 100);

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() => _elapsed += _tick);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 0..1, never quite reaching 1 while we're still waiting -- a full bar
  /// over an unfinished analysis reads as a hang.
  double get _progress {
    final ratio = _elapsed.inMilliseconds / _expectedDuration.inMilliseconds;
    return ratio >= 1 ? 0.95 : ratio * 0.95;
  }

  /// Counts 20 down to 1, then stops: the analysis can legitimately run
  /// longer than the estimate (a long video, a slow provider), and a
  /// countdown that hits zero and keeps going looks broken.
  int? get _secondsLeft {
    final left = _expectedDuration.inSeconds - _elapsed.inSeconds;
    return left >= 1 ? left : null;
  }

  int get _currentStep {
    final ratio = _elapsed.inMilliseconds / _expectedDuration.inMilliseconds;
    if (ratio >= 0.85) return 3;
    if (ratio >= 0.55) return 2;
    if (ratio >= 0.25) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<VideoProvider>().isLoading;

    // The analysis is over (either way) -- step aside and let the home
    // screen show the result or the error.
    if (!isLoading && !_closing) {
      _closing = true;
      // Stop ticking as well as closing: if this screen is the only route
      // there is nothing to pop to, and a ticker that never stops keeps the
      // frame loop busy forever.
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // pop(), not maybePop(): the PopScope below refuses maybePop so a
        // back gesture can't abandon a running analysis, and that refusal
        // would otherwise block this screen from closing itself too.
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
    }

    final secondsLeft = _secondsLeft;
    final currentStep = _currentStep;

    return PopScope(
      // Leaving mid-analysis would strand the request with nowhere to land.
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.analyzingGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: CustomPaint(painter: _AnalyzingMarkPainter()),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      '영상을 분석하고 있어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      secondsLeft != null
                          ? '잠시만 기다려 주세요 · 약 $secondsLeft초'
                          : '거의 다 됐어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 22),
                    for (var i = 0; i < _steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _StepRow(
                        label: _steps[i],
                        state: i < currentStep
                            ? _StepState.done
                            : (i == currentStep ? _StepState.active : _StepState.pending),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final pending = state == _StepState.pending;
    final color = pending ? Colors.white.withValues(alpha: 0.45) : Colors.white;

    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: switch (state) {
            _StepState.done => Icon(Icons.check_rounded, size: 17, color: color),
            _StepState.active => CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            _StepState.pending => DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.8),
                ),
              ),
          },
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

/// The handoff's mark: a white map pin with a play triangle in it, standing
/// on two elliptical rings.
class _AnalyzingMarkPainter extends CustomPainter {
  const _AnalyzingMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 130;
    final centerX = size.width / 2;

    // Rings first, so the pin stands on top of them.
    final ringRect = Rect.fromCenter(
      center: Offset(centerX, 108 * scale),
      width: 112 * scale,
      height: 30 * scale,
    );
    canvas.drawOval(
      ringRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale,
    );
    canvas.drawOval(
      ringRect.deflate(20 * scale),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale,
    );

    // Pin: a circle head tapering to a point, 80x104 inside the 130 box.
    final headCenter = Offset(centerX, 44 * scale);
    final headRadius = 40 * scale;
    final tip = Offset(centerX, 110 * scale);
    final white = Paint()..color = Colors.white;

    final pin = Path()..addOval(Rect.fromCircle(center: headCenter, radius: headRadius));
    final shoulderDy = headCenter.dy + headRadius * 0.62;
    final shoulderDx = headRadius * 0.79;
    pin
      ..moveTo(centerX - shoulderDx, shoulderDy)
      ..quadraticBezierTo(centerX - shoulderDx * 0.5, tip.dy - 14 * scale, tip.dx, tip.dy)
      ..quadraticBezierTo(centerX + shoulderDx * 0.5, tip.dy - 14 * scale, centerX + shoulderDx, shoulderDy)
      ..close();
    canvas.drawPath(pin, white);

    // Play triangle, optically centred in the head.
    final play = Path()
      ..moveTo(centerX - 11 * scale, headCenter.dy - 14 * scale)
      ..lineTo(centerX + 15 * scale, headCenter.dy)
      ..lineTo(centerX - 11 * scale, headCenter.dy + 14 * scale)
      ..close();
    canvas.drawPath(play, Paint()..color = const Color(0xFF0F7A84));
  }

  @override
  bool shouldRepaint(covariant _AnalyzingMarkPainter oldDelegate) => false;
}
