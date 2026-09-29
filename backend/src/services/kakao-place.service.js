const kakaoPlaceRepository = require('../repositories/kakao-place.repository');

const KAKAO_ID_PREFIX = 'kakao:';

/**
 * A 뚜벅이 코스 can contain places found live through Kakao's keyword search
 * (FR-17), which have no row in `places` -- their id in the snapshot is
 * "kakao:<id>". Course snapshots have no FK so they store that happily, but
 * anything keyed off a real place then fails: bookmarking is rejected for
 * not being a UUID, and a shared route's likes skip those places, so a
 * course made only of Kakao places teaches the preference model nothing.
 *
 * So when a user *keeps* a course -- saves it, or publishes it to the feed
 * -- its Kakao places are written into `places` and the snapshot's ids are
 * rewritten to the new UUIDs. Only kept courses, not every generated one:
 * a course nobody saved has no reason to add rows.
 *
 * Idempotent, and a no-op when the snapshot holds no Kakao places (a folder
 * route, or a trip itinerary, is already made of real places).
 *
 * @param {Array<object>} routeData a course snapshot
 * @returns {Promise<Array<object>>} the same snapshot with real place ids
 */
async function materializeRoutePlaces(routeData) {
  if (!Array.isArray(routeData)) return routeData;

  const kakaoPoints = routeData.filter(
    (point) =>
      point &&
      typeof point.placeId === 'string' &&
      point.placeId.startsWith(KAKAO_ID_PREFIX) &&
      point.latitude != null &&
      point.longitude != null
  );
  if (kakaoPoints.length === 0) return routeData;

  // The same place twice in one course would break the upsert's ON CONFLICT
  // ("cannot affect row a second time"), so each Kakao id goes in once.
  const byExternalId = new Map();
  for (const point of kakaoPoints) {
    const externalId = point.placeId.slice(KAKAO_ID_PREFIX.length);
    if (!externalId || byExternalId.has(externalId)) continue;
    byExternalId.set(externalId, {
      externalId,
      name: point.name,
      address: point.address ?? null,
      latitude: point.latitude,
      longitude: point.longitude,
      category: point.category ?? null,
    });
  }

  const idByExternalId = await kakaoPlaceRepository.upsertAll([...byExternalId.values()]);

  return routeData.map((point) => {
    if (!point || typeof point.placeId !== 'string' || !point.placeId.startsWith(KAKAO_ID_PREFIX)) {
      return point;
    }
    const placeId = idByExternalId.get(point.placeId.slice(KAKAO_ID_PREFIX.length));
    // A place we could not write (no coordinates) keeps its Kakao id: the
    // course still shows it, it just stays unbookmarkable.
    return placeId ? { ...point, placeId } : point;
  });
}

module.exports = { materializeRoutePlaces, KAKAO_ID_PREFIX };
