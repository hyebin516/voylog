import 'package:share_plus/share_plus.dart';

/// Shares a single place's Kakao Map link via the OS share sheet. Kept
/// behind a class (like `ItineraryShareService`) so `PlaceDetailScreen` can
/// inject a fake for widget tests instead of hitting the real platform
/// share sheet under `flutter test`.
class PlaceShareService {
  const PlaceShareService();

  /// `map.kakao.com/link/map/{name},{lat},{lng}` is Kakao's public,
  /// key-less place-link format -- opens a pin at that location in the
  /// Kakao Map app (or web) for whoever receives it.
  String buildMapUrl({required String placeName, required double latitude, required double longitude}) {
    return 'https://map.kakao.com/link/map/${Uri.encodeComponent(placeName)},$latitude,$longitude';
  }

  Future<void> shareMapLink({required String placeName, required double latitude, required double longitude}) async {
    final url = buildMapUrl(placeName: placeName, latitude: latitude, longitude: longitude);
    await SharePlus.instance.share(
      ShareParams(text: '$placeName - Voylog\n$url'),
    );
  }
}
