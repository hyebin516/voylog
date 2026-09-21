import 'package:url_launcher/url_launcher.dart';

/// Opens a place in the Kakao Map app, or in Kakao Map on the web when the
/// app isn't installed. Kept behind a class (like `PlaceShareService`) so
/// screens can inject a fake and `flutter test` never launches anything.
class KakaoMapLauncher {
  const KakaoMapLauncher();

  static const String _kakaoPlaceIdPrefix = 'kakao:';

  /// The Kakao Map app's URL scheme. A place found through Kakao search
  /// ("kakao:12345") opens its own place page; any other place is searched
  /// by name around its coordinates, which lands on the same Kakao place
  /// page when Kakao lists it and otherwise shows that spot.
  Uri appUri({
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
  }) {
    if (placeId.startsWith(_kakaoPlaceIdPrefix)) {
      return Uri.parse(
        'kakaomap://place?id=${placeId.substring(_kakaoPlaceIdPrefix.length)}',
      );
    }
    return Uri(
      scheme: 'kakaomap',
      host: 'search',
      queryParameters: {'q': name, 'p': '$latitude,$longitude'},
    );
  }

  /// Kakao Map on the web: the place page for a Kakao place, otherwise the
  /// same key-less pin link `PlaceShareService` shares.
  Uri webUri({
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
  }) {
    if (placeId.startsWith(_kakaoPlaceIdPrefix)) {
      return Uri.parse(
        'https://place.map.kakao.com/${placeId.substring(_kakaoPlaceIdPrefix.length)}',
      );
    }
    return Uri.parse(
      'https://map.kakao.com/link/map/${Uri.encodeComponent(name)},$latitude,$longitude',
    );
  }

  /// Returns false only when neither the app nor a browser could open it.
  Future<bool> open({
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    final app = appUri(
      placeId: placeId,
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
    try {
      if (await launchUrl(app, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Not installed -- fall through to the web page.
    }
    final web = webUri(
      placeId: placeId,
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
    try {
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
