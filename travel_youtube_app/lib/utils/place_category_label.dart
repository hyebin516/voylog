import 'package:flutter/material.dart';

// Korean display names for the place category codes the backend returns
// (cafe, restaurant, attraction, ...). The same wording as the AI Worker's
// recommendation reason sentences, so a card and its reason agree.
const Map<String, String> _placeCategoryLabels = {
  'cafe': '카페',
  'bakery': '베이커리',
  'restaurant': '음식점',
  'dessert': '디저트',
  'bar': '술집',
  'museum': '박물관',
  'gallery': '미술관',
  'attraction': '관광 명소',
  'shopping': '쇼핑',
  'beach': '바닷가',
  'night_view': '전망 명소',
};

/// Null for a missing, "other", or unrecognized category, so callers can
/// simply leave the label out instead of printing a raw code.
String? placeCategoryLabel(String? category) => _placeCategoryLabels[category];

/// 카테고리별 아이콘.
///
/// 장소에는 사진이 없다 -- 영상 분석은 이름만 뽑고, 공공데이터 이미지는
/// 항목마다 저작권이 달라 적재하지 않았으며, 카카오 Local API는 사진을 주지
/// 않는다. 그래서 카드의 사진 자리에 빈 이미지 아이콘이 반복됐는데, 그건
/// "사진을 불러오지 못했다"처럼 보인다. 무엇이 있는 자리인지 알려주는 편이
/// 낫다고 보고 카테고리 아이콘으로 대체했다.
const Map<String, IconData> _placeCategoryIcons = {
  'cafe': Icons.local_cafe_rounded,
  'bakery': Icons.bakery_dining_rounded,
  'restaurant': Icons.restaurant_rounded,
  'dessert': Icons.icecream_rounded,
  'bar': Icons.wine_bar_rounded,
  'museum': Icons.museum_rounded,
  'gallery': Icons.palette_rounded,
  'attraction': Icons.photo_camera_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'beach': Icons.beach_access_rounded,
  'night_view': Icons.nights_stay_rounded,
};

/// 카테고리를 모르면 지도 핀. 빈 이미지 아이콘과 달리 "자리 표시"가 아니라
/// 장소라는 뜻이 된다.
IconData placeCategoryIcon(String? category) =>
    _placeCategoryIcons[category] ?? Icons.place_rounded;
