const recommendationRepository = require('../repositories/recommendation.repository');
const tastePreferenceRepository = require('../repositories/taste-preference.repository');
const behaviorRepository = require('../repositories/behavior.repository');
const bookmarkRepository = require('../repositories/bookmark.repository');
const { callAiWorker } = require('./aiWorkerClient');

const DEFAULT_RADIUS_M = 2000;
const MAX_RADIUS_M = 5000;
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 20;
const MAX_CANDIDATES = 100;

const DEFAULT_SIMILAR_TASTE_LIMIT = 20;
const MAX_SIMILAR_TASTE_LIMIT = 50;

// Downtown/neighborhood scale -- a walking course generated from a broad
// region name (e.g. "제주", "서울") is centered on one geocoded point, not
// the whole area, so this stays small enough to still be walkable.
const WALKING_COURSE_RADIUS_M = 3000;
const MAX_WALKING_COURSE_CANDIDATES = 60;

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

async function getNearbyRecommendations({ userId, latitude, longitude, localTime, radiusMeters, limit }) {
  const radius = Math.min(radiusMeters || DEFAULT_RADIUS_M, MAX_RADIUS_M);
  const resultLimit = Math.min(limit || DEFAULT_LIMIT, MAX_LIMIT);

  const excludePlaceIds = userId ? await behaviorRepository.findHiddenPlaceIds(userId) : [];
  const candidatePlaces = await recommendationRepository.findNearby(
    latitude,
    longitude,
    radius,
    MAX_CANDIDATES,
    excludePlaceIds
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

async function getWalkingCourse({ userId, region, localTime }) {
  // Not caught here -- a GEOCODING_FAILED AppError from callAiWorker should
  // propagate to the controller unchanged, same as every other AI Worker
  // failure in this service.
  const center = await callAiWorker('/geocode', { query: region }, 10000);

  const excludePlaceIds = userId ? await behaviorRepository.findHiddenPlaceIds(userId) : [];
  const bookmarkedCandidates = await recommendationRepository.findNearby(
    center.latitude,
    center.longitude,
    WALKING_COURSE_RADIUS_M,
    MAX_WALKING_COURSE_CANDIDATES,
    excludePlaceIds,
    true // bookmarkedOnly -- pooled across all users, not just the requester
  );

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

  return callAiWorker(
    '/recommendations/walking-course',
    {
      regionName: region,
      centerLatitude: center.latitude,
      centerLongitude: center.longitude,
      localTime,
      radiusMeters: WALKING_COURSE_RADIUS_M,
      bookmarkCandidates: bookmarkedCandidates.map(toCandidate),
      userEmbedding,
      userTagScores,
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
