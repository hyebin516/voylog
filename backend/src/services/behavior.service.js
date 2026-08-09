const behaviorRepository = require('../repositories/behavior.repository');
const placeRepository = require('../repositories/place.repository');
const placeEmbeddingRepository = require('../repositories/place-embedding.repository');
const tastePreferenceRepository = require('../repositories/taste-preference.repository');
const { callAiWorker } = require('./aiWorkerClient');
const policy = require('./behavior-scoring-policy');

const MODEL_VERSION = 'hybrid-v1';

function bucketDistance(distanceMeters) {
  if (distanceMeters == null) return null;
  if (distanceMeters < 200) return '0-200m';
  if (distanceMeters < 500) return '200-500m';
  if (distanceMeters < 1000) return '500m-1km';
  if (distanceMeters < 2000) return '1-2km';
  return '2km+';
}

// Nudges the user's preference embedding and per-tag scores toward (or away
// from, for hide/not_interested) the place this behavior was on. Best-effort:
// if there's no place embedding AND no prior preference to update, there is
// nothing to persist a vector into, so it silently no-ops.
async function updatePreferenceFromBehavior(userId, placeId, action) {
  const weight = policy.weightFor(action);
  if (!weight) return;

  const [place] = await placeRepository.findByIds([placeId]);
  if (!place) return;

  const pastCount = await behaviorRepository.countPastActions(userId, placeId, action);
  const effectiveWeight = weight * policy.dampingFor(pastCount) * policy.LEARNING_RATE;

  const preference = await tastePreferenceRepository.find(userId);
  const [placeEmbeddingRow] = await placeEmbeddingRepository.findByPlaceIds([placeId]);

  let embedding = preference ? preference.embedding : null;
  let model = preference ? preference.model : null;
  let dimensions = preference ? preference.dimensions : null;

  if (placeEmbeddingRow) {
    const result = await callAiWorker(
      '/embeddings/update-preference',
      {
        currentEmbedding: preference ? preference.embedding : null,
        placeEmbedding: placeEmbeddingRow.embedding,
        weight: effectiveWeight,
      },
      15000
    );
    embedding = result.embedding;
    model = placeEmbeddingRow.model;
    dimensions = placeEmbeddingRow.dimensions;
  }

  if (!embedding) return;

  const tagScores = preference && preference.tag_scores ? { ...preference.tag_scores } : {};
  for (const tag of place.tags || []) {
    const current = tagScores[tag.code] || 0;
    tagScores[tag.code] = policy.clampTagScore(current + effectiveWeight * tag.confidence);
  }

  await tastePreferenceRepository.updateFromBehavior(userId, { embedding, tagScores, model, dimensions });
}

async function recordBehavior(userId, { placeId, action, screen, distanceMeters }) {
  await behaviorRepository.create(userId, placeId, action, {
    screen,
    distanceBucket: bucketDistance(distanceMeters),
    modelVersion: MODEL_VERSION,
  });

  await updatePreferenceFromBehavior(userId, placeId, action);
}

module.exports = { recordBehavior };
