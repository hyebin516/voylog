import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import '../core/config/env.dart';

/// Low-level bootstrap for the Kakao Maps SDK. Must be called once before
/// any `KakaoMapWidget` is built (call from main() before runApp()).
class MapService {
  MapService._();

  static void initialize() {
    AuthRepository.initialize(appKey: Env.kakaoJavascriptKey);
  }
}
