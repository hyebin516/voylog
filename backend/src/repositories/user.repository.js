const pool = require('../config/db');

async function findByProviderId(providerId) {
  const { rows } = await pool.query(
    'SELECT * FROM users WHERE provider_id = $1 AND deleted_at IS NULL',
    [providerId]
  );
  return rows[0] || null;
}

async function findById(userId) {
  const { rows } = await pool.query('SELECT * FROM users WHERE user_id = $1 AND deleted_at IS NULL', [userId]);
  return rows[0] || null;
}

async function create(user) {
  const { rows } = await pool.query(
    `INSERT INTO users (provider, provider_id, email, nickname, profile_image)
     VALUES ('kakao', $1, $2, $3, $4)
     RETURNING *`,
    [user.providerId, user.email, user.nickname, user.profileImage]
  );
  return rows[0];
}

module.exports = { findByProviderId, findById, create };
