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

// Nudges the user's preference embedding and per-tag scores by
// `effectiveWeight` (already sign/damping/learning-rate adjusted by the
// caller) toward the given place. Best-effort: if there's no place
// embedding AND no prior preference to update, there is nothing to persist
// a vector into, so it silently no-ops. Shared by both the forward nudge
// (`updatePreferenceFromBehavior`) and its reversal (`reverseScopedBehavior`)
// below -- only the sign of `effectiveWeight` differs between the two.
async function applyPreferenceNudge(userId, placeId, effectiveWeight) {
  const [place] = await placeRepository.findByIds([placeId]);
  if (!place) return;

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

async function updatePreferenceFromBehavior(userId, placeId, action) {
  const weight = policy.weightFor(action);
  if (!weight) return;

  const pastCount = await behaviorRepository.countPastActions(userId, placeId, action);
  const effectiveWeight = weight * policy.dampingFor(pastCount) * policy.LEARNING_RATE;
  await applyPreferenceNudge(userId, placeId, effectiveWeight);
}

async function recordBehavior(userId, { placeId, action, screen, distanceMeters }) {
  await behaviorRepository.create(userId, placeId, action, {
    screen,
    distanceBucket: bucketDistance(distanceMeters),
    modelVersion: MODEL_VERSION,
  });

  await updatePreferenceFromBehavior(userId, placeId, action);
}

// Best-effort reversal of one earlier `recordBehavior` call, scoped to a
// specific `screen` (currently only used to undo a shared-route "like" when
// the user unlikes it -- see shared-route.service.js). Deletes the most
// recent matching `recommendation_behaviors` row (so future decay counts
// stay accurate, as if that action never happened), then either:
//
// - Fully resets the preference row (embedding + tag_scores) when this was
//   the ONLY signal that ever formed it (no taste survey, no other behavior
//   left) -- this case can't be handled by nudging: `update_preference_embedding`
//   is `normalize(current + weight*place)`, and when `current` starts at the
//   zero vector, the result is `place/||place||` for *any* positive weight --
//   the weight magnitude never survives the normalize(), so subtracting it
//   back out is a no-op regardless of how it's computed. Confirmed by testing
//   against real data before landing this, not just reasoned about in the abstract.
// - Otherwise nudges the vector back by the same effective weight the
//   original action applied (recomputed from the post-delete count). This is
//   still only an approximation when other actions happened in between --
//   normalize() is not linear, so it moves the vector back in the right
//   direction without exactly reconstructing "as if it never happened".
async function reverseScopedBehavior(userId, placeId, action, screen) {
  const deleted = await behaviorRepository.deleteMostRecent(userId, placeId, action, screen);
  if (!deleted) return;

  const weight = policy.weightFor(action);
  if (!weight) return;

  const preference = await tastePreferenceRepository.find(userId);
  const neverSurveyed = preference && (!preference.source_tags || preference.source_tags.length === 0);
  const remainingBehaviorCount = await behaviorRepository.countAll(userId);

  if (neverSurveyed && remainingBehaviorCount === 0) {
    await tastePreferenceRepository.remove(userId);
    return;
  }

  const pastCount = await behaviorRepository.countPastActions(userId, placeId, action);
  const effectiveWeight = weight * policy.dampingFor(pastCount) * policy.LEARNING_RATE;
  await applyPreferenceNudge(userId, placeId, -effectiveWeight);
}

module.exports = { recordBehavior, reverseScopedBehavior };
