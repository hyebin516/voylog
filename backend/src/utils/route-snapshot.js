// Builds the sanitized snapshot stored in `shared_routes.route_data` when a
// saved walking course or a trip's day itinerary is published to the public
// feed. Both sources produce the identical `route_data` shape (AI Worker's
// `optimize-route` RoutePoint: order/type/hotelId/placeId/name/lat/lng/
// legDistanceM/legDurationSec) -- see itinerary.repository.js and
// saved-walking-course.repository.js, both storing that array as-is.
//
// Hotel points are dropped entirely (name, coordinates -- everything) since
// itineraries carry a real hotel address the author never agreed to publish
// to the whole app, not just the region-level courses. The first remaining
// place's leg fields are reset to null (that leg used to run from the now-
// removed hotel, so keeping it would leak a hotel-to-place distance).
//
// `placeId` and each place's coordinates ARE kept -- a place is a public
// spot, not private the way a hotel address is. shared-route.service needs
// the id to resolve each place's embedding/tags when someone likes the route
// (FR-21's like -> taste-weight integration), and the route detail screen
// needs the coordinates to draw the route on a map. Snapshots published
// before coordinates were kept are filled in by
// scripts/backfill-shared-route-coordinates.js.
function buildPublicRouteSnapshot(routeData) {
  const placePoints = [...routeData]
    .filter((point) => point.type === 'place')
    .sort((a, b) => a.order - b.order);

  const snapshot = placePoints.map((point, index) => ({
    order: index,
    type: 'place',
    placeId: point.placeId ?? null,
    name: point.name,
    latitude: point.latitude ?? null,
    longitude: point.longitude ?? null,
    legDistanceM: index === 0 ? null : point.legDistanceM,
    legDurationSec: index === 0 ? null : point.legDurationSec,
    // Walked or by bus, only on a bookmark-folder route that mixes the two --
    // without it a published 20-minute bus ride would read as a walk. The
    // guidance says which bus, between which stops.
    ...(point.legTransportMode !== undefined && {
      legTransportMode: index === 0 ? null : point.legTransportMode,
    }),
    ...(point.legGuidance !== undefined && {
      legGuidance: index === 0 ? null : point.legGuidance,
    }),
  }));

  const distances = snapshot.map((p) => p.legDistanceM).filter((d) => d != null);
  const durations = snapshot.map((p) => p.legDurationSec).filter((d) => d != null);

  return {
    routeData: snapshot,
    totalDistanceM: distances.length > 0 ? distances.reduce((a, b) => a + b, 0) : null,
    totalDurationSec: durations.length > 0 ? durations.reduce((a, b) => a + b, 0) : null,
    placeCount: snapshot.length,
  };
}

module.exports = { buildPublicRouteSnapshot };
