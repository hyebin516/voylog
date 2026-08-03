class HotelModel {
  final String hotelId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const HotelModel({
    required this.hotelId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory HotelModel.fromJson(Map<String, dynamic> json) {
    return HotelModel(
      hotelId: json['hotelId'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
