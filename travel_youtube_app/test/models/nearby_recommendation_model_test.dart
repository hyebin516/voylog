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
      'address': '서울 성동구 왕십리로 83',
      'businessHours': {
        'mon': {'open': '09:00', 'close': '21:00'},
      },
      'businessHoursIsEstimated': true,
      'tags': ['소금빵', '오션뷰'],
      'isOpen': true,
      'isOpenEstimated': true,
      'score': 0.87,
      'matchedTags': ['소금빵', '오션뷰'],
      'reason': '현재 위치에서 420m 떨어져 있어요. 지금 영업 중이에요.',
    });

    expect(rec.placeId, 'p1');
    expect(rec.distanceMeters, 420);
    expect(rec.isOpen, isTrue);
    expect(rec.isOpenEstimated, isTrue);
    expect(rec.score, 0.87);
    expect(rec.matchedTags, ['소금빵', '오션뷰']);
    // Everything the place detail screen needs travels with the card, so
    // opening it from a recommendation doesn't fetch the place again.
    expect(rec.address, '서울 성동구 왕십리로 83');
    expect(rec.businessHours!['mon'], {'open': '09:00', 'close': '21:00'});
    expect(rec.businessHoursIsEstimated, isTrue);
    expect(rec.tags, ['소금빵', '오션뷰']);
  });

  test('category and isOpen may be null (unknown), matchedTags defaults to empty', () {
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
    expect(rec.matchedTags, isEmpty);
    expect(rec.address, isNull);
    expect(rec.businessHours, isNull);
    expect(rec.businessHoursIsEstimated, isFalse);
    expect(rec.tags, isEmpty);
  });
}
