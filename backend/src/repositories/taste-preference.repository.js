const pool = require('../config/db');

async function find(userId) {
  const { rows } = await pool.query('SELECT * FROM user_preference_embeddings WHERE user_id = $1', [userId]);
  return rows[0] || null;
}

async function upsert(userId, { embedding, sourceTags, sourceText, model, dimensions }) {
  const { rows } = await pool.query(
    `INSERT INTO user_preference_embeddings (user_id, embedding, source_tags, source_text, model, dimensions)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (user_id) DO UPDATE
       SET embedding = EXCLUDED.embedding,
           source_tags = EXCLUDED.source_tags,
           source_text = EXCLUDED.source_text,
           model = EXCLUDED.model,
           dimensions = EXCLUDED.dimensions,
           updated_at = now()
     RETURNING *`,
    [userId, JSON.stringify(embedding), JSON.stringify(sourceTags), sourceText, model, dimensions]
  );
  return rows[0];
}

async function remove(userId) {
  await pool.query('DELETE FROM user_preference_embeddings WHERE user_id = $1', [userId]);
}

module.exports = { find, upsert, remove };
