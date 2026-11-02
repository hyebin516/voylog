import 'package:url_launcher/url_launcher.dart';

import '../core/config/env.dart';

/// 서버가 서빙하는 공개 문서(개인정보처리방침, 이용약관)를 브라우저로 연다.
///
/// 문서를 앱에 복사해 두지 않는 이유는 둘이 어긋나기 때문이다 -- 스토어에
/// 등록한 URL과 앱이 보여주는 내용이 다르면 그것 자체가 문제가 된다.
/// 서버의 한 파일을 양쪽이 같이 본다.
class LegalDocumentLauncher {
  const LegalDocumentLauncher();

  /// `.env`의 API 주소에서 `/api/v1`을 떼어낸 것이 문서가 있는 곳이다
  /// (`https://<도메인>/privacy`). 주소를 두 번 적지 않으려고 이렇게 뽑는다.
  static Uri _documentUri(String path) {
    final base = Env.apiBaseUrl;
    final origin = Uri.parse(base).replace(path: '', query: null).toString();
    return Uri.parse('${origin.replaceAll(RegExp(r'/$'), '')}/$path');
  }

  static Uri get privacyPolicyUri => _documentUri('privacy');
  static Uri get termsOfServiceUri => _documentUri('terms');

  /// 열지 못하면 false를 돌려준다 -- 화면이 스낵바로 알릴 수 있게.
  /// 서버가 꺼져 있거나 브라우저가 없는 기기에서도 앱이 죽으면 안 된다.
  Future<bool> openPrivacyPolicy() => _open(privacyPolicyUri);

  Future<bool> openTermsOfService() => _open(termsOfServiceUri);

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
