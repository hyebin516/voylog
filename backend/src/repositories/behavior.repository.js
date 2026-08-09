const pool = require('../config/db');

async function create(userId, placeId, action, { screen, distanceBucket, modelVersion }) {
  const { rows } = await pool.query(
    `INSERT INTO recommendation_behaviors (user_id, place_id, action, screen, distance_bucket, model_version)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [userId, placeId, action, screen || null, distanceBucket || null, modelVersion || null]
  );
  return rows[0];
}

async function countPastActions(userId, placeId, action) {
  const { rows } = await pool.query(
    'SELECT count(*)::int AS count FROM recommendation_behaviors WHERE user_id = $1 AND place_id = $2 AND action = $3',
    [userId, placeId, action]
  );
  return rows[0].count;
}

async function findHiddenPlaceIds(userId) {
  const { rows } = await pool.query(
    `SELECT DISTINCT place_id FROM recommendation_behaviors
     WHERE user_id = $1 AND action IN ('hide', 'not_interested')`,
    [userId]
  );
  return rows.map((row) => row.place_id);
}

module.exports = { create, countPastActions, findHiddenPlaceIds };
