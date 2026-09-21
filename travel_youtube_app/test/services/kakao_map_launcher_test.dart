import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/services/kakao_map_launcher.dart';

void main() {
  const launcher = KakaoMapLauncher();

  test('a Kakao search place opens its own Kakao place page', () {
    expect(
      launcher.appUri(placeId: 'kakao:12345', name: '케이락볼링장', latitude: 35.1, longitude: 129.0).toString(),
      'kakaomap://place?id=12345',
    );
    expect(
      launcher.webUri(placeId: 'kakao:12345', name: '케이락볼링장', latitude: 35.1, longitude: 129.0).toString(),
      'https://place.map.kakao.com/12345',
    );
  });

  test('any other place is searched by name around its coordinates', () {
    final app = launcher.appUri(placeId: 'uuid-1', name: '전주 경기전', latitude: 35.815, longitude: 127.15);
    expect(app.scheme, 'kakaomap');
    expect(app.host, 'search');
    expect(app.queryParameters, {'q': '전주 경기전', 'p': '35.815,127.15'});

    expect(
      launcher.webUri(placeId: 'uuid-1', name: '전주 경기전', latitude: 35.815, longitude: 127.15).toString(),
      'https://map.kakao.com/link/map/${Uri.encodeComponent('전주 경기전')},35.815,127.15',
    );
  });
}
