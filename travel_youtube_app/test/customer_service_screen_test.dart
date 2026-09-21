import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/constants/customer_service_content.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';
import 'package:travel_youtube_app/screens/customer_service_screen.dart';

void main() {
  testWidgets('shows every FAQ question and the contact email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CustomerServiceScreen()));

    for (final faq in CustomerServiceContent.faqs) {
      expect(find.text(faq.question), findsOneWidget);
    }
    // The address stays on screen as a fallback next to the in-app form.
    expect(find.textContaining(CustomerServiceContent.contactEmail), findsOneWidget);
  });

  testWidgets('the 문의 entry opens the inquiry form (FR-13)', (tester) async {
    var pushedRoute = '';
    await tester.pumpWidget(MaterialApp(
      home: const CustomerServiceScreen(),
      onGenerateRoute: (settings) {
        pushedRoute = settings.name ?? '';
        return MaterialPageRoute(builder: (_) => const SizedBox.shrink());
      },
    ));

    await tester.tap(find.byKey(const Key('supportInquiryEntry')));
    await tester.pumpAndSettle();

    expect(pushedRoute, AppRoutes.supportInquiry);
  });

  testWidgets('expanding a FAQ reveals its answer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CustomerServiceScreen()));

    final firstFaq = CustomerServiceContent.faqs.first;
    expect(find.text(firstFaq.answer), findsNothing);

    await tester.tap(find.text(firstFaq.question));
    await tester.pumpAndSettle();

    expect(find.text(firstFaq.answer), findsOneWidget);
  });
}
