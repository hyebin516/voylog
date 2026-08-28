import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/walking_course_model.dart';
import 'package:travel_youtube_app/providers/walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/walking_course_repository.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/walking_course_region_screen.dart';

const WalkingCourseModel _emptyResult = WalkingCourseModel(course: null, recommendations: []);

class FakeWalkingCourseRepository extends WalkingCourseRepository {
  String? lastRegion;

  @override
  Future<WalkingCourseModel> generate({required String region, required DateTime localTime}) async {
    lastRegion = region;
    return _emptyResult;
  }
}

Widget _wrap(WalkingCourseProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const WalkingCourseRegionScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        settings: settings,
      ),
    ),
  );
}

void main() {
  testWidgets('shows every fixed region and disables the button until one is picked', (tester) async {
    await tester.pumpWidget(_wrap(WalkingCourseProvider(repository: FakeWalkingCourseRepository())));

    expect(find.text('제주'), findsOneWidget);
    expect(find.text('서울'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a region enables the button, generates the course, and navigates to the result screen', (tester) async {
    final repository = FakeWalkingCourseRepository();
    await tester.pumpWidget(_wrap(WalkingCourseProvider(repository: repository)));

    await tester.tap(find.byKey(const Key('walkingCourseRegion_제주')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('generateCourseButton')));
    await tester.pumpAndSettle();

    expect(repository.lastRegion, '제주');
    expect(find.text('route:${AppRoutes.walkingCourseResult}'), findsOneWidget);
  });
}
