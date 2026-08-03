import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/bookmark_model.dart';

void main() {
  group('BookmarkModel.fromJson', () {
    test('parses a geocoded bookmarked place', () {
      final bookmark = BookmarkModel.fromJson({
        'bookmarkId': 'b1',
        'placeId': 'p1',
        'videoId': 'v1',
        'name': 'Place',
        'address': 'addr',
        'latitude': 35.0,
        'longitude': 129.0,
        'timestampSec': 10,
        'source': 'transcript',
        'confidence': 0.9,
        'bookmarkedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(bookmark.bookmarkId, 'b1');
      expect(bookmark.hasCoordinates, isTrue);
      expect(bookmark.bookmarkedAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
    });

    test('hasCoordinates is false when latitude/longitude are null', () {
      final bookmark = BookmarkModel.fromJson({
        'bookmarkId': 'b1',
        'placeId': 'p1',
        'videoId': null,
        'name': 'Place',
        'address': null,
        'latitude': null,
        'longitude': null,
        'timestampSec': null,
        'source': 'title',
        'confidence': 0.2,
        'bookmarkedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(bookmark.hasCoordinates, isFalse);
    });
  });
}
