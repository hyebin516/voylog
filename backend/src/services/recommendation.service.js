const recommendationRepository = require('../repositories/recommendation.repository');
const tastePreferenceRepository = require('../repositories/taste-preference.repository');
const behaviorRepository = require('../repositories/behavior.repository');
const { callAiWorker } = require('./aiWorkerClient');

const DEFAULT_RADIUS_M = 2000;
const MAX_RADIUS_M = 5000;
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 20;
const MAX_CANDIDATES = 100;

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

module.exports = { getNearbyRecommendations };
