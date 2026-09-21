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

/**
 * Refreshes what Kakao owns on a returning user's row -- never the nickname,
 * which the user can rename in this app.
 */
async function updateKakaoProfile(userId, { email, profileImage }) {
  const { rows } = await pool.query(
    `UPDATE users SET email = $1, profile_image = $2, updated_at = now()
     WHERE user_id = $3 AND deleted_at IS NULL
     RETURNING *`,
    [email, profileImage, userId]
  );
  return rows[0];
}

async function softDelete(userId) {
  await pool.query('UPDATE users SET deleted_at = now() WHERE user_id = $1', [userId]);
}

async function updateNickname(userId, nickname) {
  const { rows } = await pool.query(
    'UPDATE users SET nickname = $1, updated_at = now() WHERE user_id = $2 AND deleted_at IS NULL RETURNING *',
    [nickname, userId]
  );
  return rows[0];
}

async function findByEmail(email) {
  const { rows } = await pool.query('SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL', [email]);
  return rows[0] || null;
}

async function findByNickname(nickname) {
  const { rows } = await pool.query('SELECT * FROM users WHERE nickname = $1 AND deleted_at IS NULL', [nickname]);
  return rows[0] || null;
}

async function updatePasswordHash(userId, passwordHash) {
  const { rows } = await pool.query(
    'UPDATE users SET password_hash = $1, updated_at = now() WHERE user_id = $2 AND deleted_at IS NULL RETURNING *',
    [passwordHash, userId]
  );
  return rows[0];
}

async function createEmailUser({ email, passwordHash, nickname }) {
  const { rows } = await pool.query(
    `INSERT INTO users (provider, provider_id, email, nickname, password_hash)
     VALUES ('email', $1, $1, $2, $3)
     RETURNING *`,
    [email, nickname, passwordHash]
  );
  return rows[0];
}

module.exports = {
  findByProviderId,
  updateKakaoProfile,
  findById,
  create,
  softDelete,
  findByEmail,
  findByNickname,
  createEmailUser,
  updateNickname,
  updatePasswordHash,
};
