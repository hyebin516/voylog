import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/trip_model.dart';
import 'package:travel_youtube_app/providers/trip_provider.dart';
import 'package:travel_youtube_app/repositories/trip_repository.dart';
import 'package:travel_youtube_app/screens/trip_list_screen.dart';

class FakeTripRepository extends TripRepository {
  List<TripModel> tripsToReturn = [];
  ApiException? listError;
  TripModel? createdTrip;

  @override
  Future<List<TripModel>> listTrips() async {
    if (listError != null) throw listError!;
    return tripsToReturn;
  }

  @override
  Future<TripModel> createTrip(String name) async => createdTrip!;
}

Widget _wrap(TripProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: const TripListScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('trip detail'))),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when there are no trips yet', (tester) async {
    final repository = FakeTripRepository();
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('아직 만든 여행이 없습니다.'), findsOneWidget);
  });

  testWidgets('lists trips with their saved day count', (tester) async {
    final repository = FakeTripRepository()
      ..tripsToReturn = [
        TripModel(tripId: 't1', name: '제주도 여행', dayCount: 2, createdAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('제주도 여행'), findsOneWidget);
    expect(find.text('2일차 저장됨'), findsOneWidget);
  });

  testWidgets('creating a trip navigates to its detail screen', (tester) async {
    final repository = FakeTripRepository()..createdTrip = TripModel(tripId: 't1', name: '부산 여행', dayCount: 0, createdAt: DateTime(2026, 1, 1));
    await tester.pumpWidget(_wrap(TripProvider(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '부산 여행');
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(find.text('trip detail'), findsOneWidget);
  });
}
