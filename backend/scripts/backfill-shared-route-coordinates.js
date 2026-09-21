/**
 * Fills in place coordinates for shared routes (FR-21) published before the
 * public snapshot kept them, so their detail screen can draw the route.
 *
 *   node scripts/backfill-shared-route-coordinates.js
 *
 * A stop's coordinates come from the route it was published from (the
 * saved walking course or itinerary still holds the full route), or failing
 * that from the `places` row with that id. Hotel points were never in the
 * snapshot and are not added. Safe to re-run.
 */
const pool = require('../src/config/db');
const sharedRouteRepository = require('../src/repositories/shared-route.repository');
const savedWalkingCourseRepository = require('../src/repositories/saved-walking-course.repository');
const itineraryRepository = require('../src/repositories/itinerary.repository');
const placeRepository = require('../src/repositories/place.repository');
const isUuid = require('../src/utils/isUuid');

const hasCoordinates = (point) => point.latitude != null && point.longitude != null;

async function sourceCoordinates(route) {
  const source =
    route.source_type === 'saved_walking_course'
      ? await savedWalkingCourseRepository.findById(route.source_id)
      : await itineraryRepository.findById(route.source_id);
  const coordinates = new Map();
  for (const point of (source && source.route_data) || []) {
    if (point.type === 'place' && point.placeId && hasCoordinates(point)) {
      coordinates.set(point.placeId, { latitude: point.latitude, longitude: point.longitude });
    }
  }
  return coordinates;
}

async function main() {
  const routes = await sharedRouteRepository.findAllActive();
  let updated = 0;
  let stillMissing = 0;

  for (const route of routes) {
    const missing = route.route_data.filter((point) => !hasCoordinates(point));
    if (missing.length === 0) continue;

    // eslint-disable-next-line no-await-in-loop
    const coordinates = await sourceCoordinates(route);
    const placeIds = missing.map((point) => point.placeId).filter((id) => id && !coordinates.has(id) && isUuid(id));
    // eslint-disable-next-line no-await-in-loop
    for (const place of await placeRepository.findByIds(placeIds)) {
      if (place.latitude != null && place.longitude != null) {
        coordinates.set(place.place_id, { latitude: Number(place.latitude), longitude: Number(place.longitude) });
      }
    }

    const routeData = route.route_data.map((point) =>
      hasCoordinates(point) || !coordinates.has(point.placeId) ? point : { ...point, ...coordinates.get(point.placeId) }
    );
    stillMissing += routeData.filter((point) => !hasCoordinates(point)).length;
    // eslint-disable-next-line no-await-in-loop
    await sharedRouteRepository.updateRouteData(route.shared_route_id, routeData);
    updated += 1;
    console.log(`  ${route.title}: ${missing.length - routeData.filter((p) => !hasCoordinates(p)).length}/${missing.length} stops filled`);
  }

  console.log(`Backfill done: ${updated} routes updated, ${stillMissing} stops still without coordinates`);
}

main()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
