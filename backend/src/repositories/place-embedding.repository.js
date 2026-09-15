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

/**
 * Same as upsert, for many places in one statement.
 * @param {Array<{placeId, embedding, model, dimensions, sourceTextHash}>} rows
 */
async function upsertMany(rows) {
  if (rows.length === 0) return;
  const values = [];
  const placeholders = rows.map((row, i) => {
    const offset = i * 5;
    values.push(row.placeId, JSON.stringify(row.embedding), row.model, row.dimensions, row.sourceTextHash);
    return `($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4}, $${offset + 5})`;
  });
  await pool.query(
    `INSERT INTO place_embeddings (place_id, embedding, model, dimensions, source_text_hash)
     VALUES ${placeholders.join(', ')}
     ON CONFLICT (place_id) DO UPDATE
       SET embedding = EXCLUDED.embedding,
           model = EXCLUDED.model,
           dimensions = EXCLUDED.dimensions,
           source_text_hash = EXCLUDED.source_text_hash,
           updated_at = now()`,
    values
  );
}

async function findByPlaceIds(placeIds) {
  if (placeIds.length === 0) return [];
  const { rows } = await pool.query(
    'SELECT place_id, embedding, model, dimensions FROM place_embeddings WHERE place_id = ANY($1::uuid[])',
    [placeIds]
  );
  return rows;
}

module.exports = { upsert, upsertMany, findByPlaceIds };
