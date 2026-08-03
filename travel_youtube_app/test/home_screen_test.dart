import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/providers/video_provider.dart';
import 'package:travel_youtube_app/screens/home_screen.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

void main() {
  testWidgets('HomeScreen shows the URL input and analyze button', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VideoProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('분석할 유튜브 영상 URL을 입력하세요'), findsOneWidget);
    expect(find.byKey(const Key('urlField')), findsOneWidget);
    expect(find.text('분석하기'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('urlField')), '');
    await tester.tap(find.text('분석하기'));
    await tester.pump();

    expect(find.text('URL을 먼저 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('HomeScreen shows the hashtag search bar', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => VideoProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('해시태그로 브이로그 탐색'), findsOneWidget);
    expect(find.text('탐색하기'), findsOneWidget);
    expect(find.byIcon(Icons.tag_rounded), findsOneWidget);
  });

  testWidgets('tapping search with an empty hashtag does nothing (no loading state)', (tester) async {
    final videoProvider = VideoProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: videoProvider,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.tap(find.text('탐색하기'));
    await tester.pump();

    expect(videoProvider.searchState, ViewState.idle);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
