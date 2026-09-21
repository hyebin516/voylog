import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/support_inquiry_model.dart';
import 'package:travel_youtube_app/repositories/support_inquiry_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

const _inquiryJson = {
  'inquiryId': 'i1',
  'email': 'a@b.com',
  'category': 'bug',
  'message': '분석이 멈춰요',
  'createdAt': '2026-09-21T00:58:06.590Z',
};

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('submit posts the category code and maps the created inquiry', () async {
    final adapter = FakeDioAdapter(statusCode: 201, body: const {'success': true, 'data': _inquiryJson});
    DioClient().dio.httpClientAdapter = adapter;

    final inquiry = await SupportInquiryRepository().submit(
      email: 'a@b.com',
      category: SupportInquiryCategory.bug,
      message: '분석이 멈춰요',
    );

    expect(adapter.lastOptions?.path, '/support-inquiries');
    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.data, {'email': 'a@b.com', 'category': 'bug', 'message': '분석이 멈춰요'});
    expect(inquiry.inquiryId, 'i1');
  });

  test('listMine maps the inquiry list', () async {
    DioClient().dio.httpClientAdapter = FakeDioAdapter(statusCode: 200, body: const {
      'success': true,
      'data': {
        'inquiries': [_inquiryJson],
      },
    });

    final inquiries = await SupportInquiryRepository().listMine();

    expect(inquiries, hasLength(1));
    expect(inquiries.first.category, SupportInquiryCategory.bug);
  });

  test('turns a rejected inquiry into an ApiException', () async {
    DioClient().dio.httpClientAdapter = FakeDioAdapter(statusCode: 400, body: const {
      'success': false,
      'error': {'code': 'INVALID_REQUEST', 'message': 'bad'},
    });

    expect(
      () => SupportInquiryRepository().submit(
        email: 'nope',
        category: SupportInquiryCategory.other,
        message: 'x',
      ),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_REQUEST')),
    );
  });
}
