const pool = require('../config/db');

/**
 * Claims a device's push token for this user. A phone that a second user
 * logs into must stop getting the first user's notifications, so the token
 * moves rather than duplicating.
 */
async function upsert(userId, token, platform) {
  const { rows } = await pool.query(
    `INSERT INTO device_tokens (token, user_id, platform)
     VALUES ($1, $2, $3)
     ON CONFLICT (token) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           platform = EXCLUDED.platform,
           updated_at = now()
     RETURNING *`,
    [token, userId, platform]
  );
  return rows[0];
}

async function findByUser(userId) {
  const { rows } = await pool.query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
  return rows;
}

/** Logout, or a token FCM says no longer exists. */
async function remove(token) {
  await pool.query('DELETE FROM device_tokens WHERE token = $1', [token]);
}

module.exports = { upsert, findByUser, remove };
