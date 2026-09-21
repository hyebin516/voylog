const { buildPublicRouteSnapshot } = require('../../src/utils/route-snapshot');

describe('buildPublicRouteSnapshot', () => {
  it('drops hotel points entirely and re-sequences the remaining places from 0', () => {
    const routeData = [
      { order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: 'Hotel A', legDistanceM: null, legDurationSec: null },
      { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: 'Place 1', legDistanceM: 500, legDurationSec: 300 },
      { order: 2, type: 'place', hotelId: null, placeId: 'p2', name: 'Place 2', legDistanceM: 400, legDurationSec: 200 },
      { order: 3, type: 'hotel', hotelId: 'h1', placeId: null, name: 'Hotel A', legDistanceM: 100, legDurationSec: 60 },
    ];

    const result = buildPublicRouteSnapshot(routeData);

    expect(result.routeData).toEqual([
      { order: 0, type: 'place', placeId: 'p1', name: 'Place 1', latitude: null, longitude: null, legDistanceM: null, legDurationSec: null },
      { order: 1, type: 'place', placeId: 'p2', name: 'Place 2', latitude: null, longitude: null, legDistanceM: 400, legDurationSec: 200 },
    ]);
    expect(result.placeCount).toBe(2);
  });

  it('keeps how each leg of a bookmark-folder route is travelled, and which bus', () => {
    const routeData = [
      { order: 0, type: 'place', placeId: 'p1', name: 'A', legDistanceM: null, legDurationSec: null, legTransportMode: null },
      { order: 1, type: 'place', placeId: 'p2', name: 'B', legDistanceM: 400, legDurationSec: 300, legTransportMode: 'walk' },
      {
        order: 2,
        type: 'place',
        placeId: 'p3',
        name: 'C',
        legDistanceM: 5200,
        legDurationSec: 1200,
        legTransportMode: 'transit',
        legGuidance: '600번 · 온양온천역 → 신정호',
      },
    ];

    const { routeData: snapshot } = buildPublicRouteSnapshot(routeData);

    expect(snapshot.map((p) => p.legTransportMode)).toEqual([null, 'walk', 'transit']);
    expect(snapshot[2].legGuidance).toBe('600번 · 온양온천역 → 신정호');
  });

  it('keeps place coordinates but never a hotel point', () => {
    const routeData = [
      { order: 0, type: 'hotel', hotelId: 'h1', name: 'Hotel A', latitude: 33.1, longitude: 126.1 },
      { order: 1, type: 'place', placeId: 'p1', name: 'Place 1', latitude: 33.5, longitude: 126.5, legDistanceM: 500, legDurationSec: 300 },
    ];

    const { routeData: snapshot } = buildPublicRouteSnapshot(routeData);

    expect(snapshot).toHaveLength(1);
    expect(snapshot[0]).toMatchObject({ placeId: 'p1', latitude: 33.5, longitude: 126.5 });
    expect(JSON.stringify(snapshot)).not.toContain('33.1');
  });

  it('nulls out the first remaining place leg (it used to run from the dropped hotel)', () => {
    const routeData = [
      { order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: 'Hotel A', legDistanceM: null, legDurationSec: null },
      { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: 'Place 1', legDistanceM: 850, legDurationSec: 640 },
    ];

    const result = buildPublicRouteSnapshot(routeData);

    expect(result.routeData[0].legDistanceM).toBeNull();
    expect(result.routeData[0].legDurationSec).toBeNull();
  });

  it('recomputes totalDistanceM/totalDurationSec by summing only the remaining legs', () => {
    const routeData = [
      { order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: 'Hotel A', legDistanceM: null, legDurationSec: null },
      { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: 'Place 1', legDistanceM: 500, legDurationSec: 300 },
      { order: 2, type: 'place', hotelId: null, placeId: 'p2', name: 'Place 2', legDistanceM: 400, legDurationSec: 200 },
      { order: 3, type: 'place', hotelId: null, placeId: 'p3', name: 'Place 3', legDistanceM: 300, legDurationSec: 100 },
      { order: 4, type: 'hotel', hotelId: 'h2', placeId: null, name: 'Hotel B', legDistanceM: 200, legDurationSec: 90 },
    ];

    const result = buildPublicRouteSnapshot(routeData);

    // Excludes the leg into the first place (nulled) and the leg into the
    // dropped end-hotel entirely -- only the two inter-place legs count.
    expect(result.totalDistanceM).toBe(700);
    expect(result.totalDurationSec).toBe(300);
  });

  it('returns null totals when there is only one place left (no legs at all)', () => {
    const routeData = [
      { order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: 'Hotel A', legDistanceM: null, legDurationSec: null },
      { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: 'Place 1', legDistanceM: 500, legDurationSec: 300 },
    ];

    const result = buildPublicRouteSnapshot(routeData);

    expect(result.totalDistanceM).toBeNull();
    expect(result.totalDurationSec).toBeNull();
    expect(result.placeCount).toBe(1);
  });

  it('sorts by order before stripping, regardless of input array order', () => {
    const routeData = [
      { order: 2, type: 'place', hotelId: null, placeId: 'p2', name: 'Place 2', legDistanceM: 400, legDurationSec: 200 },
      { order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: 'Hotel A', legDistanceM: null, legDurationSec: null },
      { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: 'Place 1', legDistanceM: 500, legDurationSec: 300 },
    ];

    const result = buildPublicRouteSnapshot(routeData);

    expect(result.routeData.map((p) => p.name)).toEqual(['Place 1', 'Place 2']);
  });

  it('never leaks a hotel id or hotel coordinates, but keeps placeId and place coordinates (map + like -> taste-weight lookups)', () => {
    const routeData = [
      { order: 0, type: 'hotel', hotelId: 'h1', placeId: null, name: 'Hotel A', latitude: 1, longitude: 1 },
      { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: 'Place 1', latitude: 2, longitude: 2 },
    ];

    const result = buildPublicRouteSnapshot(routeData);

    for (const point of result.routeData) {
      expect(point).not.toHaveProperty('hotelId');
      expect(point.latitude).not.toBe(1);
    }
    expect(result.routeData[0]).toMatchObject({ placeId: 'p1', latitude: 2, longitude: 2 });
  });
});
