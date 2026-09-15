/// Fixed option lists for the region/theme/duration recommendation wizard.
class RecommendationOptions {
  RecommendationOptions._();

  static const List<String> regions = [
    '양양', '제주도', '서울', '부산', '강릉', '경주', '전주', '여수',
    '속초', '인천', '대구', '대전', '광주', '전남', '경남', '충북', '충남',
  ];

  static const List<String> themes = [
    '체험 액티비티', 'SNS 핫플레이스', '자연', '유명 관광지',
    '여유롭게 힐링', '문화 예술 역사', '여행지 느낌 물씬', '쇼핑', '먹방',
  ];

  static const List<String> durations = ['당일치기', '1박 2일', '2박 3일', '3박 4일', '4박 5일 이상'];
}
