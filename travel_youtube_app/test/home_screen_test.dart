import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen shows the URL input and analyze button', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VideoProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('분석할 유튜브 영상 URL을 입력하세요'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('분석하기'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('분석하기'));
    await tester.pump();

    expect(find.text('URL을 먼저 입력해 주세요.'), findsOneWidget);
  });
}
