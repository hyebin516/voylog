/// Public datasets the app's place data comes from, besides analyzed vlogs.
/// Both are 공공누리 제1유형, which permits use only with the source credited,
/// so any screen showing these places carries [PublicDataSources.caption]
/// and 고객센터 lists the full detail.
class PublicDataSource {
  final String provider;
  final String dataset;

  const PublicDataSource({required this.provider, required this.dataset});
}

class PublicDataSources {
  PublicDataSources._();

  static const List<PublicDataSource> all = [
    PublicDataSource(provider: '한국관광공사', dataset: '국문 관광정보 서비스(TourAPI)'),
    PublicDataSource(provider: '소상공인시장진흥공단', dataset: '상가(상권)정보'),
  ];

  static const String license = '공공누리 제1유형(출처표시)';

  static const String caption = '장소 정보 출처: 한국관광공사, 소상공인시장진흥공단';
}
