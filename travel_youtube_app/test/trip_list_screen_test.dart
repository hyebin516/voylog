import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/trip_model.dart';
import 'package:travel_youtube_app/models/user_model.dart';
import 'package:travel_youtube_app/providers/auth_provider.dart';
import 'package:travel_youtube_app/providers/trip_provider.dart';
import 'package:travel_youtube_app/repositories/auth_repository.dart';
import 'package:travel_youtube_app/repositories/trip_repository.dart';
import 'package:travel_youtube_app/screens/trip_list_screen.dart';

const UserModel _user = UserModel(userId: 'u1', email: 'a@b.com', nickname: 'Nagyeong', profileImage: null);

class FakeTripRepository extends TripRepository {
  List<TripModel> tripsToReturn = [];
  ApiException? listError;
  TripModel? createdTrip;
  final List<String> deleteCalls = [];

  @override
  Future<List<TripModel>> listTrips() async {
    if (listError != null) throw listError!;
    return tripsToReturn;
  }

  @override
  Future<TripModel> createTrip(String name, {DateTime? startDate, DateTime? endDate}) async => createdTrip!;

  @override
  Future<void> deleteTrip(String tripId) async => deleteCalls.add(tripId);
}

class FakeAuthRepository extends AuthRepository {
  @override
  Future<UserModel> loginWithKakao(String kakaoAccessToken) async => _user;
}

Future<AuthProvider> _authenticatedProvider() async {
  final authProvider = AuthProvider(repository: FakeAuthRepository());
  await authProvider.loginWithKakao('kakao-token');
  return authProvider;
}

Widget _wrap(TripProvider provider, AuthProvider authProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider.value(value: authProvider),
    ],
    child: MaterialApp(
      home: const TripListScreen(),
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('trip detail'))),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when there are no trips yet', (tester) async {
    final repository = FakeTripRepository();
    await tester.pumpWidget(_wrap(TripProvider(repository: repository), await _authenticatedProvider()));
    await tester.pumpAndSettle();

    expect(find.text('아직 만든 여행이 없습니다.'), findsOneWidget);
  });

  testWidgets('lists trips with their saved day count', (tester) async {
    final repository = FakeTripRepository()
      ..tripsToReturn = [
        TripModel(tripId: 't1', name: '제주도 여행', dayCount: 2, createdAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(TripProvider(repository: repository), await _authenticatedProvider()));
    await tester.pumpAndSettle();

    expect(find.text('제주도 여행'), findsOneWidget);
    expect(find.text('2일차 저장됨'), findsOneWidget);
  });

  testWidgets('"만들기" stays disabled until both a name and a date range are set, then creates the trip', (
    tester,
  ) async {
    final repository = FakeTripRepository()..createdTrip = TripModel(tripId: 't1', name: '부산 여행', dayCount: 0, createdAt: DateTime(2026, 1, 1));
    await tester.pumpWidget(_wrap(TripProvider(repository: repository), await _authenticatedProvider()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // Name only, no dates yet -- "만들기" must stay disabled (dates are
    // mandatory now, not just the name).
    await tester.enterText(find.byType(TextField), '부산 여행');
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, '만들기')).onPressed, isNull);

    // Pick a (single-day) date range via the real showDateRangePicker.
    await tester.tap(find.text('여행 날짜 선택'));
    await tester.pumpAndSettle();
    final today = DateTime.now().day.toString();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, '만들기')).onPressed, isNotNull);

    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(find.text('trip detail'), findsOneWidget);
  });

  testWidgets('deleting a trip removes it from the list after confirmation', (tester) async {
    final repository = FakeTripRepository()
      ..tripsToReturn = [
        TripModel(tripId: 't1', name: '제주도 여행', dayCount: 2, createdAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(TripProvider(repository: repository), await _authenticatedProvider()));
    await tester.pumpAndSettle();
    expect(find.text('제주도 여행'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, ['t1']);
    expect(find.text('제주도 여행'), findsNothing);
    expect(find.text('아직 만든 여행이 없습니다.'), findsOneWidget);
  });

  testWidgets('shows a login-required prompt for guests instead of an error', (tester) async {
    final repository = FakeTripRepository();
    await tester.pumpWidget(_wrap(TripProvider(repository: repository), AuthProvider(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    expect(find.text('로그인이 필요해요'), findsOneWidget);
    expect(find.text('아직 만든 여행이 없습니다.'), findsNothing);
  });
}
