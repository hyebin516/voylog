import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/widgets/report_route_sheet.dart';

import 'fakes/fake_shared_route_repository.dart';

const _routeId = 'route-1';

Future<void> _pumpSheet(WidgetTester tester, FakeSharedRouteRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReportRouteSheet(sharedRouteId: _routeId, repository: repository),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('공개 동선 신고 시트', () {
    testWidgets('사유를 고르기 전에는 신고 버튼이 눌리지 않는다', (tester) async {
      final repository = FakeSharedRouteRepository();
      await _pumpSheet(tester, repository);

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '신고하기'));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('신고하기'));
      await tester.pump();
      expect(repository.reports, isEmpty);
    });

    testWidgets('사유를 고르면 그 코드로 신고가 접수된다', (tester) async {
      final repository = FakeSharedRouteRepository();
      await _pumpSheet(tester, repository);

      await tester.tap(find.text('욕설이나 혐오 표현이 있어요'));
      await tester.pump();

      await tester.tap(find.text('신고하기'));
      await tester.pumpAndSettle();

      expect(repository.reports, hasLength(1));
      expect(repository.reports.single.id, _routeId);
      expect(repository.reports.single.reason, 'offensive');
    });

    testWidgets('자세한 내용을 적으면 함께 전달된다', (tester) async {
      final repository = FakeSharedRouteRepository();
      await _pumpSheet(tester, repository);

      await tester.tap(find.text('그 밖의 이유'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '제목이 다른 앱 광고예요');

      await tester.tap(find.text('신고하기'));
      await tester.pumpAndSettle();

      expect(repository.reports.single.reason, 'other');
      expect(repository.reports.single.detail, '제목이 다른 앱 광고예요');
    });

    testWidgets('접수에 실패하면 시트가 닫히지 않고 안내가 뜬다', (tester) async {
      final repository = FakeSharedRouteRepository()
        ..reportError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');
      await _pumpSheet(tester, repository);

      await tester.tap(find.text('스팸이거나 광고예요'));
      await tester.pump();
      await tester.tap(find.text('신고하기'));
      await tester.pumpAndSettle();

      expect(find.text('신고를 접수하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      // Still open, so the user can try again without re-picking a reason.
      expect(find.text('이 동선을 신고할까요?'), findsOneWidget);
    });

    testWidgets('사유 목록은 백엔드가 받는 코드와 같은 6가지다', (tester) async {
      expect(
        reportReasons.map((r) => r.code).toList(),
        ['spam', 'offensive', 'sexual', 'illegal', 'copyright', 'other'],
      );
    });
  });
}
