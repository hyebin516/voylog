const pool = require('../config/db');

async function find(userId) {
  const { rows } = await pool.query('SELECT * FROM user_preference_embeddings WHERE user_id = $1', [userId]);
  return rows[0] || null;
}

async function upsert(userId, { embedding, sourceTags, sourceText, model, dimensions }) {
  // A fresh survey submission resets learned tag_scores to a clean baseline
  // (1.0 per selected tag) rather than merging with whatever behavior had
  // nudged them to before -- re-taking the survey means "start over".
  const tagScores = Object.fromEntries(sourceTags.map((tag) => [tag, 1.0]));
  const { rows } = await pool.query(
    `INSERT INTO user_preference_embeddings (user_id, embedding, source_tags, source_text, model, dimensions, tag_scores)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (user_id) DO UPDATE
       SET embedding = EXCLUDED.embedding,
           source_tags = EXCLUDED.source_tags,
           source_text = EXCLUDED.source_text,
           model = EXCLUDED.model,
           dimensions = EXCLUDED.dimensions,
           tag_scores = EXCLUDED.tag_scores,
           updated_at = now()
     RETURNING *`,
    [userId, JSON.stringify(embedding), JSON.stringify(sourceTags), sourceText, model, dimensions, JSON.stringify(tagScores)]
  );
  return rows[0];
}

// Behavior-driven updates (phase 5) only ever touch embedding/tag_scores --
// source_tags/source_text/model stay whatever the last taste survey set (or
// the '[]'/'' defaults below, the first time a user with no survey history
// triggers a learnable behavior).
async function updateFromBehavior(userId, { embedding, tagScores, model, dimensions }) {
  const { rows } = await pool.query(
    `INSERT INTO user_preference_embeddings (user_id, embedding, source_tags, source_text, model, dimensions, tag_scores)
     VALUES ($1, $2, '[]'::jsonb, '', $3, $4, $5)
     ON CONFLICT (user_id) DO UPDATE
       SET embedding = EXCLUDED.embedding,
           tag_scores = EXCLUDED.tag_scores,
           updated_at = now()
     RETURNING *`,
    [userId, JSON.stringify(embedding), model, dimensions, JSON.stringify(tagScores)]
  );
  return rows[0];
}

async function remove(userId) {
  await pool.query('DELETE FROM user_preference_embeddings WHERE user_id = $1', [userId]);
}

module.exports = { find, upsert, updateFromBehavior, remove };
