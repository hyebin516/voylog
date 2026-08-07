const pool = require('../config/db');

async function upsert(placeId, { embedding, model, dimensions, sourceTextHash }) {
  await pool.query(
    `INSERT INTO place_embeddings (place_id, embedding, model, dimensions, source_text_hash)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (place_id) DO UPDATE
       SET embedding = EXCLUDED.embedding,
           model = EXCLUDED.model,
           dimensions = EXCLUDED.dimensions,
           source_text_hash = EXCLUDED.source_text_hash,
           updated_at = now()`,
    [placeId, JSON.stringify(embedding), model, dimensions, sourceTextHash]
  );
}

async function findByPlaceIds(placeIds) {
  if (placeIds.length === 0) return [];
  const { rows } = await pool.query(
    'SELECT place_id, embedding FROM place_embeddings WHERE place_id = ANY($1::uuid[])',
    [placeIds]
  );
  return rows;
}

module.exports = { upsert, findByPlaceIds };
