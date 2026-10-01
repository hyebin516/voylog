import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/intro_screen.dart';

import 'helpers/phone_viewport.dart';

Widget _wrap(List<String> pushed) => MaterialApp(
      home: const IntroScreen(),
      onGenerateRoute: (settings) {
        pushed.add(settings.name ?? '');
        return MaterialPageRoute<void>(
          builder: (_) => Text('route:${settings.name}'),
          settings: settings,
        );
      },
    );

void main() {
  testWidgets('shows the headline, the pitch and the way in', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_wrap([]));
    await tester.pump();

    expect(find.textContaining('되는 순간'), findsOneWidget);
    expect(find.textContaining('AI가 영상 속 장소를 찾아'), findsOneWidget);
    expect(find.text('동선 만들기 시작'), findsOneWidget);
  });

  testWidgets('the CTA replaces onboarding with the login screen', (
    tester,
  ) async {
    // pushReplacement, not push: coming back to the pitch from login would
    // be a dead end.
    usePhoneViewport(tester);
    final pushed = <String>[];
    await tester.pumpWidget(_wrap(pushed));
    await tester.pump();

    await tester.tap(find.byKey(const Key('introStartButton')));
    await tester.pumpAndSettle();

    expect(pushed, contains(AppRoutes.login));
    expect(find.text('동선 만들기 시작'), findsNothing);
  });
}
