import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/providers/recommendation_wizard_provider.dart';
import 'package:travel_youtube_app/screens/recommendation_region_screen.dart';

Widget _wrap(RecommendationWizardProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const RecommendationRegionScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('theme screen'))),
    ),
  );
}

void main() {
  testWidgets('next button is disabled until a region is selected', (tester) async {
    final provider = RecommendationWizardProvider();
    await tester.pumpWidget(_wrap(provider));

    expect(find.text('다음 (0개 선택됨)'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a region enables the next button and navigates on tap', (tester) async {
    final provider = RecommendationWizardProvider();
    await tester.pumpWidget(_wrap(provider));

    await tester.tap(find.byKey(const Key('region_제주')));
    await tester.pump();

    expect(provider.selectedRegions, {'제주'});
    expect(find.text('다음 (1개 선택됨)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('regionNextButton')));
    await tester.pumpAndSettle();

    expect(find.text('theme screen'), findsOneWidget);
  });
}
