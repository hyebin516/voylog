import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/similar_taste_recommendation_model.dart';

Map<String, dynamic> _recJson({String placeId = 'p1'}) => {
      'placeId': placeId,
      'name': '흑돼지집',
      'latitude': 33.51,
      'longitude': 126.51,
      'address': '제주 제주시 관덕로 32',
      'category': 'restaurant',
      'score': 1.6,
      'contributorCount': 2,
      'reason': '취향이 비슷한 사용자 2명이 북마크한 곳이에요.',
    };

void main() {
  group('SimilarTasteRecommendationModel.fromJson', () {
    test('parses all fields', () {
      final rec = SimilarTasteRecommendationModel.fromJson(_recJson());

      expect(rec.placeId, 'p1');
      expect(rec.name, '흑돼지집');
      expect(rec.latitude, 33.51);
      expect(rec.longitude, 126.51);
      expect(rec.address, '제주 제주시 관덕로 32');
      expect(rec.category, 'restaurant');
      expect(rec.score, 1.6);
      expect(rec.contributorCount, 2);
      expect(rec.reason, '취향이 비슷한 사용자 2명이 북마크한 곳이에요.');
    });

    test('category may be null', () {
      final json = _recJson()..['category'] = null;
      expect(SimilarTasteRecommendationModel.fromJson(json).category, isNull);
    });

    test('address may be missing', () {
      final json = _recJson()..remove('address');
      expect(SimilarTasteRecommendationModel.fromJson(json).address, isNull);
    });
  });

  group('SimilarTasteResultModel.fromJson', () {
    test('parses hasPreference and recommendations', () {
      final result = SimilarTasteResultModel.fromJson({
        'hasPreference': true,
        'recommendations': [_recJson(placeId: 'p1'), _recJson(placeId: 'p2')],
      });

      expect(result.hasPreference, isTrue);
      expect(result.recommendations, hasLength(2));
    });

    test('hasPreference false with no recommendations', () {
      final result = SimilarTasteResultModel.fromJson({'hasPreference': false, 'recommendations': []});

      expect(result.hasPreference, isFalse);
      expect(result.recommendations, isEmpty);
    });

    test('recommendations defaults to an empty list when missing', () {
      final result = SimilarTasteResultModel.fromJson({'hasPreference': true});
      expect(result.recommendations, isEmpty);
    });
  });
}
