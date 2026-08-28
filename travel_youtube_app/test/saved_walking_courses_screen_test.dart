import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/saved_walking_course_model.dart';
import 'package:travel_youtube_app/providers/saved_walking_course_provider.dart';
import 'package:travel_youtube_app/repositories/saved_walking_course_repository.dart';
import 'package:travel_youtube_app/screens/saved_walking_courses_screen.dart';

SavedWalkingCourseModel _course(String id, String region, {int? totalDistanceM, int? totalDurationSec}) {
  return SavedWalkingCourseModel(
    savedCourseId: id,
    region: region,
    routeType: 'roundTrip',
    transportMode: 'walk',
    totalDistanceM: totalDistanceM,
    totalDurationSec: totalDurationSec,
    routeData: const [],
    createdAt: DateTime(2026, 8, 28),
  );
}

class FakeSavedWalkingCourseRepository extends SavedWalkingCourseRepository {
  List<SavedWalkingCourseModel> coursesToReturn = [];
  ApiException? listError;

  @override
  Future<List<SavedWalkingCourseModel>> list() async {
    if (listError != null) throw listError!;
    return coursesToReturn;
  }
}

Widget _wrap(SavedWalkingCourseProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const SavedWalkingCoursesScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('course detail'))),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when there are no saved courses yet', (tester) async {
    final repository = FakeSavedWalkingCourseRepository();
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('저장된 코스가 없습니다.'), findsOneWidget);
  });

  testWidgets('lists saved courses with their region and distance/duration', (tester) async {
    final repository = FakeSavedWalkingCourseRepository()
      ..coursesToReturn = [_course('sc1', '제주', totalDistanceM: 2119, totalDurationSec: 1897)];
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('제주'), findsOneWidget);
    expect(find.textContaining('2.1km'), findsOneWidget);
    expect(find.textContaining('31분'), findsOneWidget);
  });

  testWidgets('shows an error view with a retry option when loading fails', (tester) async {
    final repository = FakeSavedWalkingCourseRepository()
      ..listError = const ApiException(code: 'NETWORK_ERROR', message: 'boom');
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
  });

  testWidgets('tapping a saved course navigates to its detail screen', (tester) async {
    final repository = FakeSavedWalkingCourseRepository()..coursesToReturn = [_course('sc1', '제주')];
    await tester.pumpWidget(_wrap(SavedWalkingCourseProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('제주'));
    await tester.pumpAndSettle();

    expect(find.text('course detail'), findsOneWidget);
  });
}
