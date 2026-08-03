const pool = require('../config/db');

async function findByIds(placeIds) {
  const { rows } = await pool.query(
    'SELECT * FROM places WHERE place_id = ANY($1::uuid[]) AND deleted_at IS NULL',
    [placeIds]
  );
  return rows;
}

module.exports = { findByIds };
