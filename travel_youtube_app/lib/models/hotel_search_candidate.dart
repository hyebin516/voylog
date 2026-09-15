import 'hotel_model.dart';

/// One Kakao keyword-search result for the hotel-search bar -- not yet a
/// saved [HotelModel] (no `hotelId`) until the user picks it and it's
/// created via `POST /hotels`.
class HotelSearchCandidate {
  final String placeId;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;

  const HotelSearchCandidate({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory HotelSearchCandidate.fromJson(Map<String, dynamic> json) {
    return HotelSearchCandidate(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// Not-yet-saved [HotelModel] (empty `hotelId`) ready to pass to
  /// `HotelRepository.createHotel`/`HotelProvider.createHotel`.
  HotelModel toHotelModel() {
    return HotelModel(
      hotelId: '',
      name: name,
      address: address ?? name,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
