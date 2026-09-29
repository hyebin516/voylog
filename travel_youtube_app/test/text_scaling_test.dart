import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/theme/app_theme.dart';

/// The OS text-size setting is honoured but bounded. It scales text and not
/// the icons, avatars or fixed-size badges the handoff specifies, so an
/// unbounded setting pulls the type/icon ratio away from the design and
/// eventually pushes labels out of the rows they sit in.
void main() {
  Future<double> scaleUnder(WidgetTester tester, double osScale) async {
    late double applied;
    tester.platformDispatcher.textScaleFactorTestValue = osScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        // The same hook the app passes to MaterialApp.builder.
        builder: AppTextScaling.wrap,
        home: Builder(
          builder: (context) {
            applied = MediaQuery.textScalerOf(context).scale(100) / 100;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return applied;
  }

  testWidgets('the default setting is left alone', (tester) async {
    expect(await scaleUnder(tester, 1.0), closeTo(1.0, 0.001));
  });

  testWidgets('a larger setting is honoured up to the cap', (tester) async {
    // The test device sits at 1.1, which passes through untouched.
    expect(await scaleUnder(tester, 1.1), closeTo(1.1, 0.001));
  });

  testWidgets('beyond the cap the text stops growing', (tester) async {
    expect(await scaleUnder(tester, 1.3), closeTo(AppTextScaling.max, 0.001));
    expect(await scaleUnder(tester, 2.0), closeTo(AppTextScaling.max, 0.001));
  });

  testWidgets('a very small setting still stays readable', (tester) async {
    expect(await scaleUnder(tester, 0.5), closeTo(AppTextScaling.min, 0.001));
  });
}
