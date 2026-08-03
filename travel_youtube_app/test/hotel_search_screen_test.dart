import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/providers/hotel_provider.dart';
import 'package:travel_youtube_app/screens/hotel_search_screen.dart';

import 'fakes/fake_map_widget.dart';

void main() {
  testWidgets('HotelSearchScreen enables save after picking a location and entering a name', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HotelProvider(),
        child: const MaterialApp(
          home: HotelSearchScreen(
            role: HotelSelectionRole.start,
            mapRepository: FakeMapRepository(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('시작 호텔 선택'), findsOneWidget);
    expect(find.textContaining('fake-map center='), findsOneWidget);

    // Simulate the user dragging the map to settle on a new center.
    await tester.tap(find.text('simulate-drag'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '부산 시그니엘 호텔');
    expect(find.text('이 위치를 호텔로 저장'), findsOneWidget);
  });
}
