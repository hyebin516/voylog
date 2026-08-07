const recommendationRepository = require('../repositories/recommendation.repository');
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
  };
}

async function getNearbyRecommendations({ latitude, longitude, localTime, radiusMeters, limit }) {
  const radius = Math.min(radiusMeters || DEFAULT_RADIUS_M, MAX_RADIUS_M);
  const resultLimit = Math.min(limit || DEFAULT_LIMIT, MAX_LIMIT);

  const candidatePlaces = await recommendationRepository.findNearby(latitude, longitude, radius, MAX_CANDIDATES);
  if (candidatePlaces.length === 0) {
    return { recommendations: [] };
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
    },
    10000
  );
}

module.exports = { getNearbyRecommendations };
