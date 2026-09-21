import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/support_inquiry_model.dart';

void main() {
  test('fromJson maps every field and resolves the category code', () {
    final inquiry = SupportInquiryModel.fromJson({
      'inquiryId': 'i1',
      'email': 'a@b.com',
      'category': 'bug',
      'message': '분석이 멈춰요',
      'createdAt': '2026-09-21T00:58:06.590Z',
    });

    expect(inquiry.inquiryId, 'i1');
    expect(inquiry.email, 'a@b.com');
    expect(inquiry.category, SupportInquiryCategory.bug);
    expect(inquiry.message, '분석이 멈춰요');
    expect(inquiry.createdAt.isUtc, isFalse);
  });

  test('falls back to 기타 for a category the app does not know yet', () {
    expect(SupportInquiryCategory.fromCode('refund'), SupportInquiryCategory.other);
  });

  test('every category has the code the backend validates', () {
    expect(
      SupportInquiryCategory.values.map((c) => c.code).toList(),
      ['analysis', 'route', 'account', 'bug', 'other'],
    );
  });
}
