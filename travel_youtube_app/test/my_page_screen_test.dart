import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/screens/my_page_screen.dart';

Widget _wrap() {
  return ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: MaterialApp(
      home: const MyPageScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => Scaffold(body: Text('route:${settings.name}'))),
    ),
  );
}

void main() {
  testWidgets('shows entries for bookmarks, bookmark folders, trips, customer service, and settings', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('북마크'), findsOneWidget);
    expect(find.text('북마크 폴더'), findsOneWidget);
    expect(find.text('내 여행'), findsOneWidget);
    expect(find.text('취향 설정'), findsOneWidget);
    expect(find.text('비슷한 취향 추천'), findsOneWidget);
    expect(find.text('뚜벅이 코스'), findsOneWidget);
    expect(find.text('내 코스 목록'), findsOneWidget);
    expect(find.text('고객센터'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
  });

  testWidgets('tapping 뚜벅이 코스 navigates to the walking course region route', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('뚜벅이 코스'));
    await tester.pumpAndSettle();

    expect(find.text('route:/walking-course/region'), findsOneWidget);
  });

  testWidgets('tapping 내 코스 목록 navigates to the saved walking courses route', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('내 코스 목록'));
    await tester.pumpAndSettle();

    expect(find.text('route:/walking-courses/saved'), findsOneWidget);
  });

  testWidgets('tapping 취향 설정 navigates to the taste preferences route', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('취향 설정'));
    await tester.pumpAndSettle();

    expect(find.text('route:/taste-preferences'), findsOneWidget);
  });

  testWidgets('tapping 비슷한 취향 추천 navigates to the similar taste recommendations route', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('비슷한 취향 추천'));
    await tester.pumpAndSettle();

    expect(find.text('route:/recommendations/similar-taste'), findsOneWidget);
  });

  testWidgets('tapping 북마크 폴더 navigates to the bookmark folders route', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('북마크 폴더'));
    await tester.pumpAndSettle();

    expect(find.text('route:/bookmark-folders'), findsOneWidget);
  });

  testWidgets('tapping 고객센터 navigates to the customer service route', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();

    expect(find.text('route:/customer-service'), findsOneWidget);
  });
}
