import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/support_inquiry_model.dart';
import 'package:travel_youtube_app/providers/support_inquiry_provider.dart';
import 'package:travel_youtube_app/repositories/support_inquiry_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

SupportInquiryModel _inquiry(String id) => SupportInquiryModel(
      inquiryId: id,
      email: 'a@b.com',
      category: SupportInquiryCategory.bug,
      message: '분석이 멈춰요',
      createdAt: DateTime(2026, 9, 21),
    );

class FakeSupportInquiryRepository implements SupportInquiryRepository {
  List<SupportInquiryModel> listResult = [];
  ApiException? listError;
  SupportInquiryModel? submitResult;
  ApiException? submitError;
  ({String email, SupportInquiryCategory category, String message})? lastSubmit;

  @override
  Future<List<SupportInquiryModel>> listMine() async {
    if (listError != null) throw listError!;
    return listResult;
  }

  @override
  Future<SupportInquiryModel> submit({
    required String email,
    required SupportInquiryCategory category,
    required String message,
  }) async {
    lastSubmit = (email: email, category: category, message: message);
    if (submitError != null) throw submitError!;
    return submitResult!;
  }
}

void main() {
  late FakeSupportInquiryRepository repository;
  late SupportInquiryProvider provider;

  setUp(() {
    repository = FakeSupportInquiryRepository();
    provider = SupportInquiryProvider(repository: repository);
  });

  group('loadInquiries', () {
    test('stores the history on success', () async {
      repository.listResult = [_inquiry('i1')];

      await provider.loadInquiries();

      expect(provider.state, ViewState.success);
      expect(provider.inquiries, hasLength(1));
    });

    test('surfaces a friendly message on failure', () async {
      repository.listError = const ApiException(code: 'JWT_EXPIRED', message: 'boom');

      await provider.loadInquiries();

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('submit', () {
    test('sends the inquiry and puts it at the top of the history', () async {
      repository.listResult = [_inquiry('old')];
      await provider.loadInquiries();
      repository.submitResult = _inquiry('new');

      final sent = await provider.submit(
        email: 'a@b.com',
        category: SupportInquiryCategory.route,
        message: '동선이 이상해요',
      );

      expect(sent, isTrue);
      expect(repository.lastSubmit?.category, SupportInquiryCategory.route);
      expect(provider.inquiries.first.inquiryId, 'new');
      expect(provider.isSubmitting, isFalse);
    });

    test('returns false and keeps the history unchanged when it fails', () async {
      repository.submitError = const ApiException(code: 'INVALID_REQUEST', message: 'bad');

      final sent = await provider.submit(
        email: 'a@b.com',
        category: SupportInquiryCategory.other,
        message: 'x',
      );

      expect(sent, isFalse);
      expect(provider.errorMessage, isNotNull);
      expect(provider.inquiries, isEmpty);
      expect(provider.isSubmitting, isFalse);
    });
  });
}
