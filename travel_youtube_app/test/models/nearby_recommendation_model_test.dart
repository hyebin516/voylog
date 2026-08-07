import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/nearby_recommendation_model.dart';

void main() {
  test('NearbyRecommendationModel.fromJson parses a full recommendation', () {
    final rec = NearbyRecommendationModel.fromJson({
      'placeId': 'p1',
      'name': '예시 베이커리 카페',
      'latitude': 37.545,
      'longitude': 127.057,
      'distanceMeters': 420,
      'category': 'bakery',
      'isOpen': true,
      'isOpenEstimated': true,
      'score': 0.87,
      'reason': '현재 위치에서 420m 떨어져 있어요. 지금 영업 중이에요.',
    });

    expect(rec.placeId, 'p1');
    expect(rec.distanceMeters, 420);
    expect(rec.isOpen, isTrue);
    expect(rec.isOpenEstimated, isTrue);
    expect(rec.score, 0.87);
  });

  test('category and isOpen may be null (unknown)', () {
    final rec = NearbyRecommendationModel.fromJson({
      'placeId': 'p1',
      'name': 'Place',
      'latitude': 37.5,
      'longitude': 127.0,
      'distanceMeters': 100,
      'category': null,
      'isOpen': null,
      'isOpenEstimated': false,
      'score': 0.5,
      'reason': '현재 위치에서 100m 떨어져 있어요.',
    });

    expect(rec.category, isNull);
    expect(rec.isOpen, isNull);
  });
}
