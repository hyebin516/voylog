const crypto = require('crypto');
const placeEmbeddingRepository = require('../repositories/place-embedding.repository');
const { callAiWorker } = require('./aiWorkerClient');
const { buildPlaceEmbeddingText } = require('../utils/place-embedding-text');

// Matches the AI Worker's MAX_EMBEDDING_BATCH_SIZE.
const EMBEDDING_BATCH_SIZE = 200;
const EMBEDDING_BATCH_TIMEOUT_MS = 20000;

/**
 * Fills in embeddings for candidate places that don't have one yet, and
 * stores them so the next request finds them.
 *
 * Public-dataset places (migration 025) are imported without embeddings:
 * hundreds of thousands of 1536-dim vectors would be tens of GB and cost
 * money for places nobody ever looks at. Instead the places a user is
 * actually being recommended get embedded the first time it matters --
 * which is only when that user has a taste embedding to compare against.
 *
 * Best-effort: on any failure the places are returned as they were and
 * scoring simply goes without the similarity signal for them.
 *
 * @param {object[]} places rows with `place_id` and a possibly-null `embedding`
 * @returns {Promise<object[]>} the same places, embeddings filled where possible
 */
async function ensurePlaceEmbeddings(places) {
  const missing = places.filter((place) => !place.embedding);
  if (missing.length === 0) return places;

  const generated = new Map();
  for (let start = 0; start < missing.length; start += EMBEDDING_BATCH_SIZE) {
    const batch = missing.slice(start, start + EMBEDDING_BATCH_SIZE);
    const texts = batch.map(buildPlaceEmbeddingText);
    try {
      // eslint-disable-next-line no-await-in-loop
      const result = await callAiWorker('/embeddings/generate-batch', { texts }, EMBEDDING_BATCH_TIMEOUT_MS);
      const rows = batch.map((place, i) => ({
        placeId: place.place_id,
        embedding: result.embeddings[i],
        model: result.model,
        dimensions: result.dimensions,
        sourceTextHash: crypto.createHash('sha256').update(texts[i]).digest('hex'),
      }));
      // eslint-disable-next-line no-await-in-loop
      await placeEmbeddingRepository.upsertMany(rows);
      rows.forEach((row) => generated.set(row.placeId, row.embedding));
    } catch (err) {
      // no-op: embedding is an enhancement, not a requirement
    }
  }

  return places.map((place) =>
    generated.has(place.place_id) ? { ...place, embedding: generated.get(place.place_id) } : place
  );
}

module.exports = { ensurePlaceEmbeddings };
