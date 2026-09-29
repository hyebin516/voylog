import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/itinerary_model.dart';
import 'package:travel_youtube_app/utils/route_paths.dart';

RoutePointModel _point(int order, {List<List<double>>? path}) => RoutePointModel(
      order: order,
      type: 'place',
      hotelId: null,
      placeId: 'p$order',
      name: 'P$order',
      latitude: 37.0 + order,
      longitude: 127.0 + order,
      legPath: path,
    );

void main() {
  test('returns one entry per leg, skipping the first stop', () {
    // The first stop has no arriving leg, so a 3-stop route has 2 legs.
    final legs = routeLegPathsOf([
      _point(0),
      _point(1, path: [
        [37.1, 127.1],
        [37.2, 127.2]
      ]),
      _point(2, path: [
        [37.2, 127.2],
        [37.3, 127.3]
      ]),
    ]);

    expect(legs, hasLength(2));
    expect(legs.first, [
      [37.1, 127.1],
      [37.2, 127.2]
    ]);
  });

  test('keeps the roads it has and joins the failed leg with a straight line', () {
    // Measured on a real folder route: 3 of 4 legs came back with geometry
    // and one walk lookup failed. Dropping all of it would have thrown away
    // 448 real coordinates over the one that didn't resolve.
    final legs = routeLegPathsOf([
      _point(0),
      _point(1, path: [
        [37.1, 127.1],
        [37.15, 127.15]
      ]),
      _point(2), // Kakao failed for this leg
      _point(3, path: [
        [37.25, 127.25],
        [37.3, 127.3]
      ]),
    ]);

    expect(legs, hasLength(3));
    expect(legs[0], hasLength(2));
    // The gap is bridged stop-to-stop, so the line stays continuous.
    expect(legs[1], [
      [38.0, 128.0],
      [39.0, 129.0]
    ]);
    expect(legs[2], hasLength(2));
  });

  test('falls back to nothing when no leg has geometry at all', () {
    // Routes saved before paths were captured -- the map draws its own
    // straight line through the markers.
    expect(routeLegPathsOf([_point(0), _point(1), _point(2)]), isEmpty);
  });

  test('treats an empty path as missing', () {
    expect(routeLegPathsOf([_point(0), _point(1, path: const [])]), isEmpty);
  });

  test('has no legs for a single stop', () {
    expect(
        routeLegPathsOf([
          _point(0, path: [
            [37.1, 127.1]
          ])
        ]),
        isEmpty);
  });

  test('ignores stops that have no coordinates to draw', () {
    const noCoords = RoutePointModel(
      order: 1,
      type: 'place',
      hotelId: null,
      placeId: 'p-nowhere',
      name: '좌표 없음',
      latitude: null,
      longitude: null,
    );

    final legs = routeLegPathsOf([
      _point(0),
      noCoords,
      _point(2, path: [
        [37.2, 127.2],
        [37.3, 127.3]
      ]),
    ]);

    expect(legs, hasLength(1));
    expect(legs.first, [
      [37.2, 127.2],
      [37.3, 127.3]
    ]);
  });
}
