/// 폴더에 넣을 장소를 찾을 때 한 줄에 해당하는 것.
///
/// 검색창은 하나지만 결과는 두 곳에서 온다 -- 이미 북마크해 둔 장소와
/// 카카오 키워드 검색 결과. 어느 쪽인지는 [isBookmarked]로 구분하고,
/// 화면은 그에 따라 "담아둔 곳" 표시만 다르게 보여준다.
class PlaceSearchResultModel {
  /// 'bookmark' 또는 'kakao'.
  final String origin;

  /// 이미 북마크한 장소일 때만 있다.
  final String? bookmarkId;

  /// 이미 `places`에 있는 장소일 때만 있다.
  final String? placeId;

  /// 카카오에서 온 장소일 때 그 쪽 식별자. 폴더에 넣을 때 서버로 보낸다.
  final String? kakaoPlaceId;

  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? category;

  const PlaceSearchResultModel({
    required this.origin,
    required this.name,
    this.bookmarkId,
    this.placeId,
    this.kakaoPlaceId,
    this.address,
    this.latitude,
    this.longitude,
    this.category,
  });

  bool get isBookmarked => origin == 'bookmark';

  factory PlaceSearchResultModel.fromJson(Map<String, dynamic> json) {
    return PlaceSearchResultModel(
      origin: json['origin'] as String,
      bookmarkId: json['bookmarkId'] as String?,
      placeId: json['placeId'] as String?,
      kakaoPlaceId: json['kakaoPlaceId'] as String?,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String?,
    );
  }

  /// 폴더에 넣을 때 서버로 보내는 형태. 아직 `places`에 없는 장소라
  /// 서버가 적재부터 해야 하므로 이름과 좌표를 같이 보낸다.
  Map<String, dynamic> toAddPlaceBody() => {
        'kakaoPlaceId': kakaoPlaceId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (category != null) 'category': category,
      };
}
