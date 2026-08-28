import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/place_summary_model.dart';

void main() {
  group('PlaceSummaryModel.fromJson', () {
    test('parses an available summary', () {
      final summary = PlaceSummaryModel.fromJson({
        'available': true,
        'pros': '뷰가 좋다는 평이 많아요.',
        'cons': '웨이팅이 길다는 평이 많아요.',
        'sourceCount': 2,
      });

      expect(summary.available, isTrue);
      expect(summary.pros, '뷰가 좋다는 평이 많아요.');
      expect(summary.cons, '웨이팅이 길다는 평이 많아요.');
      expect(summary.sourceCount, 2);
    });

    test('parses an unavailable summary with null pros/cons', () {
      final summary = PlaceSummaryModel.fromJson({
        'available': false,
        'pros': null,
        'cons': null,
        'sourceCount': 1,
      });

      expect(summary.available, isFalse);
      expect(summary.pros, isNull);
      expect(summary.cons, isNull);
      expect(summary.sourceCount, 1);
    });
  });
}
