import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/services/legal_document_launcher.dart';

void main() {
  group('공개 문서 주소', () {
    test('API 주소에서 /api/v1을 떼어낸 곳을 가리킨다', () {
      // 앱이 문서를 따로 들고 있지 않고 서버가 서빙하는 한 벌을 본다.
      // 스토어에 등록한 URL과 앱이 여는 URL이 같아야 한다.
      expect(LegalDocumentLauncher.privacyPolicyUri.path, '/privacy');
      expect(LegalDocumentLauncher.termsOfServiceUri.path, '/terms');
    });

    test('두 문서가 같은 호스트를 쓴다', () {
      expect(
        LegalDocumentLauncher.privacyPolicyUri.origin,
        LegalDocumentLauncher.termsOfServiceUri.origin,
      );
    });

    test('주소에 /api가 남아 있지 않다', () {
      // 문서는 API가 아니라 사람이 여는 페이지다.
      expect(LegalDocumentLauncher.privacyPolicyUri.toString(), isNot(contains('/api')));
      expect(LegalDocumentLauncher.termsOfServiceUri.toString(), isNot(contains('/api')));
    });
  });
}
