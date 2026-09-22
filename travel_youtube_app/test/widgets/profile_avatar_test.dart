import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/widgets/profile_avatar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('when there is no photo', () {
    testWidgets('falls back to the person glyph for a null url', (tester) async {
      await tester.pumpWidget(_wrap(const ProfileAvatar(imageUrl: null)));

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('treats an empty url as no photo', (tester) async {
      await tester.pumpWidget(_wrap(const ProfileAvatar(imageUrl: '')));

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  testWidgets('loads the photo when there is one', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileAvatar(imageUrl: 'https://k.kakaocdn.net/profile.jpg')));

    // flutter_test's HttpClient refuses real requests, so the image never
    // decodes -- the point here is that it tried, and that the fallback is
    // what the user sees meanwhile rather than an empty circle.
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('keeps the circle at the requested size', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileAvatar(imageUrl: null, size: 64)));

    final box = tester.getSize(find.byType(ProfileAvatar));
    expect(box, const Size(64, 64));
  });

  testWidgets('a failed download leaves the fallback in place, not a broken image', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileAvatar(imageUrl: 'https://k.kakaocdn.net/gone.jpg')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
