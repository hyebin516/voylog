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
