import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/video_provider.dart';
import '../utils/view_state.dart';

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
/// Pops `true` once the analysis succeeds and `false` if the user cancels a
/// failure, so the caller can hand off the result the same way whether it
/// came from the first attempt or from 다시 시도.
///
/// Closes itself once the analysis succeeds. A failure keeps this screen up
/// and turns it into the error state: the message, 다시 시도 and 취소. The
/// home screen used to show that error inline, under the input, where it
/// shared the page with everything else and offered no way to dismiss it.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.youtubeUrl});

  /// Kept so 다시 시도 can run the same analysis again from here, without
  /// sending the user back to the input to press 분석하기 a second time.
  final String youtubeUrl;

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

  void _retry() {
    final videoProvider = context.read<VideoProvider>();
    setState(() {
      _elapsed = Duration.zero;
      _closing = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() => _elapsed += _tick);
    });
    unawaited(videoProvider.analyze(widget.youtubeUrl));
  }

  void _cancel() {
    // Drop the failure before leaving, so nothing downstream treats this
    // abandoned attempt as the current state of the 분석 tab.
    context.read<VideoProvider>().dismissAnalysisError();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final isLoading = videoProvider.isLoading;

    if (videoProvider.state == ViewState.error) {
      // Stop the countdown: it is measuring a request that is already over.
      _timer?.cancel();
      return _buildFailure(videoProvider.errorMessage);
    }

    // Succeeded -- step aside and let the result take over.
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
        if (navigator.canPop()) navigator.pop(true);
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


  Widget _buildFailure(String? message) {
    return PopScope(
      // Back is the same as 취소 here: it must still clear the failure.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
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
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.priority_high_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      '분석하지 못했어요',
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
                      message ?? '잠시 후 다시 시도해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 34),
                    _FailureButton(
                      label: '다시 시도',
                      filled: true,
                      onTap: _retry,
                    ),
                    const SizedBox(height: 12),
                    _FailureButton(
                      label: '취소',
                      filled: false,
                      onTap: _cancel,
                    ),
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

/// A pill sized for the failure state. The shared [PrimaryButton] paints the
/// teal brand gradient, which disappears against this screen's teal
/// background, so these two are white-on-teal instead.
class _FailureButton extends StatelessWidget {
  const _FailureButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: filled
            ? BorderSide.none
            : BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.4),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: filled ? AppColors.primary : Colors.white,
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

/// The handoff's mark, traced from the prototype: a white pin standing on
/// two elliptical rings.
///
/// The 130x130 box holds an 80x104 pin at the top, centred, and a 120x34
/// pair of ellipses at the bottom (`left:5 bottom:0`).
class _AnalyzingMarkPainter extends CustomPainter {
  const _AnalyzingMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 130;

    // Rings: cx 60 cy 17, rx 58/ry 15 and rx 40/ry 10, offset by (5, 96).
    Offset ring(double x, double y) => Offset((5 + x) * scale, (96 + y) * scale);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawOval(
      Rect.fromCenter(center: ring(60, 17), width: 116 * scale, height: 30 * scale),
      ringPaint..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.drawOval(
      Rect.fromCenter(center: ring(60, 17), width: 80 * scale, height: 20 * scale),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // Pin: the 80x104 svg sits at the top, horizontally centred.
    Offset pin(double x, double y) => Offset((25 + x) * scale, y * scale);

    // "M40 102 C40 102 4 62 4 38 A36 36 0 0 1 76 38 C76 62 40 102 40 102Z"
    final body = Path()
      ..moveTo(pin(40, 102).dx, pin(40, 102).dy)
      ..cubicTo(pin(40, 102).dx, pin(40, 102).dy, pin(4, 62).dx, pin(4, 62).dy, pin(4, 38).dx, pin(4, 38).dy)
      ..arcToPoint(
        pin(76, 38),
        radius: Radius.circular(36 * scale),
        clockwise: true,
      )
      ..cubicTo(pin(76, 62).dx, pin(76, 62).dy, pin(40, 102).dx, pin(40, 102).dy, pin(40, 102).dx, pin(40, 102).dy)
      ..close();
    canvas.drawPath(body, Paint()..color = Colors.white);

    // "M32 24 L56 38 L32 52 Z", filled and stroked so the corners round off.
    final play = Path()
      ..moveTo(pin(32, 24).dx, pin(32, 24).dy)
      ..lineTo(pin(56, 38).dx, pin(56, 38).dy)
      ..lineTo(pin(32, 52).dx, pin(32, 52).dy)
      ..close();
    const playColor = Color(0xFF0F7A84);
    canvas.drawPath(play, Paint()..color = playColor);
    canvas.drawPath(
      play,
      Paint()
        ..color = playColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalyzingMarkPainter oldDelegate) => false;
}
