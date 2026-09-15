const recommendationRepository = require('../repositories/recommendation.repository');
const tastePreferenceRepository = require('../repositories/taste-preference.repository');
const behaviorRepository = require('../repositories/behavior.repository');
const bookmarkRepository = require('../repositories/bookmark.repository');
const { callAiWorker } = require('./aiWorkerClient');
const { ensurePlaceEmbeddings } = require('./place-embedding.service');

const DEFAULT_RADIUS_M = 2000;
const MAX_RADIUS_M = 5000;
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 20;
const MAX_CANDIDATES = 100;

// The 내 주변 추천 screen's filter tabs (음식점 / 카페 / 놀거리). Filtering
// happens here, before scoring, not on the client: the client only ever
// gets the top 20, and in the evening the time-of-day hint ranks
// restaurants first, so filtering those 20 for cafes found none at all.
const NEARBY_CATEGORY_GROUPS = {
  restaurant: ['restaurant', 'dessert', 'bar'],
  cafe: ['cafe', 'bakery'],
  play: ['attraction', 'museum', 'gallery', 'shopping', 'beach', 'night_view', 'other'],
};

const DEFAULT_SIMILAR_TASTE_LIMIT = 20;
const MAX_SIMILAR_TASTE_LIMIT = 50;

// Downtown/neighborhood scale -- a walking course generated from a broad
// region name (e.g. "제주", "서울") is centered on one geocoded point, not
// the whole area, so this stays small enough to still be walkable.
const WALKING_COURSE_RADIUS_M = 3000;

// Sentinel id for the user-chosen start/end point of a walking course. It
// is not a `hotels` row -- the point is ephemeral and only lives inside
// the course snapshot -- so the frontend uses this to tell it apart from a
// real trip hotel and from the region-center fallback.
const WALKING_COURSE_START_POINT_ID = 'start-point';
const MAX_WALKING_COURSE_CANDIDATES = 60;
// Every stored place near the course center -- vlog places and public
// dataset places (migration 025) -- not only bookmarked ones. Bookmarks
// alone were a handful per area, so courses kept cycling the same stops.
const MAX_WALKING_COURSE_PLACE_CANDIDATES = 150;

function toCandidate(place) {
  return {
    placeId: place.place_id,
    name: place.name,
    latitude: Number(place.latitude),
    longitude: Number(place.longitude),
    category: place.category,
    businessHours: place.business_hours,
    embedding: place.embedding,
    tags: place.tags || [],
  };
}

async function getNearbyRecommendations({ userId, latitude, longitude, localTime, radiusMeters, limit, categoryGroup }) {
  const radius = Math.min(radiusMeters || DEFAULT_RADIUS_M, MAX_RADIUS_M);
  const resultLimit = Math.min(limit || DEFAULT_LIMIT, MAX_LIMIT);

  const excludePlaceIds = userId ? await behaviorRepository.findHiddenPlaceIds(userId) : [];
  let candidatePlaces = await recommendationRepository.findNearby(
    latitude,
    longitude,
    radius,
    MAX_CANDIDATES,
    excludePlaceIds,
    false,
    categoryGroup ? NEARBY_CATEGORY_GROUPS[categoryGroup] : null
  );
  if (candidatePlaces.length === 0) {
    return { recommendations: [] };
  }

  let userEmbedding = null;
  let userTagScores = {};
  if (userId) {
    const preference = await tastePreferenceRepository.find(userId);
    if (preference) {
      userEmbedding = preference.embedding;
      // tag_scores is the learned, behavior-nudged strength per tag. Rows
      // from before behavior tracking existed (or that haven't had a
      // learnable behavior yet) fall back to a flat 1.0 per surveyed tag --
      // this reproduces phase 4's plain presence-match exactly.
      userTagScores =
        preference.tag_scores || Object.fromEntries((preference.source_tags || []).map((tag) => [tag, 1.0]));
    }
  }

  // Similarity needs both sides embedded. Without a taste embedding there's
  // nothing to compare with, so dataset places are left unembedded.
  if (userEmbedding) {
    candidatePlaces = await ensurePlaceEmbeddings(candidatePlaces);
  }

  return callAiWorker(
    '/recommendations/nearby-score',
    {
      latitude,
      longitude,
      localTime,
      radiusMeters: radius,
      limit: resultLimit,
      candidates: candidatePlaces.map(toCandidate),
      userEmbedding,
      userTagScores,
    },
    10000
  );
}

async function getWalkingCourse({
  userId,
  region,
  localTime,
  mood,
  walkDuration,
  startLatitude,
  startLongitude,
  startName,
  avoidPlaceIds,
}) {
  // An explicit start point makes the course begin and end somewhere the
  // user chose instead of at the region's center. It's an ephemeral
  // coordinate, not a saved hotel -- a walking course start has nothing to
  // do with the trip planner's accommodation list. Optional, so the flow
  // stays usable logged-out, which is the point of FR-17's cold start.
  let startPoint = null;
  if (startLatitude != null && startLongitude != null) {
    startPoint = {
      pointId: WALKING_COURSE_START_POINT_ID,
      name: startName || '출발 지점',
      latitude: startLatitude,
      longitude: startLongitude,
    };
  }

  // A chosen start point is also where the course's places are searched
  // for. Searching around the region's center instead produced the exact
  // same stops with or without a start point -- only the route's endpoints
  // moved, so the choice looked like it did nothing. The region is then
  // just the course's label, and there's nothing to geocode.
  //
  // Otherwise, not caught here -- a GEOCODING_FAILED AppError from
  // callAiWorker should propagate to the controller unchanged, same as
  // every other AI Worker failure in this service.
  const center = startPoint
    ? { latitude: startPoint.latitude, longitude: startPoint.longitude }
    : await callAiWorker('/geocode', { query: region }, 10000);

  const excludePlaceIds = userId ? await behaviorRepository.findHiddenPlaceIds(userId) : [];
  const bookmarkedCandidates = await recommendationRepository.findNearby(
    center.latitude,
    center.longitude,
    WALKING_COURSE_RADIUS_M,
    MAX_WALKING_COURSE_CANDIDATES,
    excludePlaceIds,
    true // bookmarkedOnly -- pooled across all users, not just the requester
  );
  const bookmarkedIds = new Set(bookmarkedCandidates.map((place) => place.place_id));
  let placeCandidates = (
    await recommendationRepository.findNearby(
      center.latitude,
      center.longitude,
      WALKING_COURSE_RADIUS_M,
      MAX_WALKING_COURSE_PLACE_CANDIDATES,
      excludePlaceIds,
      false
    )
  ).filter((place) => !bookmarkedIds.has(place.place_id));

  let userEmbedding = null;
  let userTagScores = {};
  if (userId) {
    const preference = await tastePreferenceRepository.find(userId);
    if (preference) {
      userEmbedding = preference.embedding;
      userTagScores =
        preference.tag_scores || Object.fromEntries((preference.source_tags || []).map((tag) => [tag, 1.0]));
    }
  }

  // Same rule as the nearby list: only embed when there's a taste to compare.
  if (userEmbedding) {
    placeCandidates = await ensurePlaceEmbeddings(placeCandidates);
  }

  return callAiWorker(
    '/recommendations/walking-course',
    {
      regionName: region,
      centerLatitude: center.latitude,
      centerLongitude: center.longitude,
      localTime,
      radiusMeters: WALKING_COURSE_RADIUS_M,
      bookmarkCandidates: bookmarkedCandidates.map(toCandidate),
      placeCandidates: placeCandidates.map(toCandidate),
      userEmbedding,
      userTagScores,
      mood,
      walkDuration,
      startPoint,
      avoidPlaceIds: avoidPlaceIds || [],
    },
    15000
  );
}

function toSimilarTasteCandidate(place) {
  return {
    placeId: place.place_id,
    name: place.name,
    latitude: Number(place.latitude),
    longitude: Number(place.longitude),
    category: place.category,
  };
}

async function getSimilarTasteRecommendations({ userId, limit }) {
  const resultLimit = Math.min(limit || DEFAULT_SIMILAR_TASTE_LIMIT, MAX_SIMILAR_TASTE_LIMIT);

  const myPreference = await tastePreferenceRepository.find(userId);
  if (!myPreference || !myPreference.embedding) {
    // Not an error -- just means there's nothing to compare against yet.
    return { recommendations: [], hasPreference: false };
  }

  const others = await tastePreferenceRepository.findAllExcept(userId);
  if (others.length === 0) {
    return { recommendations: [], hasPreference: true };
  }

  const myBookmarkedPlaceIds = (await bookmarkRepository.findAllByUser(userId)).map((b) => b.place_id);
  const hiddenPlaceIds = await behaviorRepository.findHiddenPlaceIds(userId);
  const excludePlaceIds = [...myBookmarkedPlaceIds, ...hiddenPlaceIds];

  const otherUserIds = others.map((o) => o.user_id);
  const bookmarksByOthers = await bookmarkRepository.findByUsers(otherUserIds, excludePlaceIds);

  const bookmarksByUser = {};
  for (const row of bookmarksByOthers) {
    (bookmarksByUser[row.user_id] ||= []).push(toSimilarTasteCandidate(row));
  }

  const result = await callAiWorker(
    '/recommendations/similar-taste-score',
    {
      userEmbedding: myPreference.embedding,
      otherUsers: others.map((o) => ({
        userId: o.user_id,
        embedding: o.embedding,
        bookmarkedPlaces: bookmarksByUser[o.user_id] || [],
      })),
      limit: resultLimit,
    },
    10000
  );

  return { ...result, hasPreference: true };
}

module.exports = { getNearbyRecommendations, getWalkingCourse, getSimilarTasteRecommendations };
