const pool = require('../config/db');

const OTP_TTL_MINUTES = 5;
const VERIFIED_WINDOW_MINUTES = 15;
const MAX_ATTEMPTS = 5;

async function create(email, codeHash) {
  const { rows } = await pool.query(
    `INSERT INTO email_otps (email, code_hash, expires_at)
     VALUES ($1, $2, now() + interval '${OTP_TTL_MINUTES} minutes')
     RETURNING *`,
    [email, codeHash]
  );
  return rows[0];
}

async function findLatestUnverifiedByEmail(email) {
  const { rows } = await pool.query(
    `SELECT * FROM email_otps
     WHERE email = $1 AND verified_at IS NULL
     ORDER BY created_at DESC
     LIMIT 1`,
    [email]
  );
  return rows[0] || null;
}

async function findLatestVerifiedByEmail(email) {
  const { rows } = await pool.query(
    `SELECT * FROM email_otps
     WHERE email = $1 AND verified_at IS NOT NULL
       AND verified_at > now() - interval '${VERIFIED_WINDOW_MINUTES} minutes'
     ORDER BY verified_at DESC
     LIMIT 1`,
    [email]
  );
  return rows[0] || null;
}

async function markVerified(otpId) {
  await pool.query('UPDATE email_otps SET verified_at = now() WHERE otp_id = $1', [otpId]);
}

async function incrementAttempts(otpId) {
  await pool.query('UPDATE email_otps SET attempts = attempts + 1 WHERE otp_id = $1', [otpId]);
}

async function deleteByEmail(email) {
  await pool.query('DELETE FROM email_otps WHERE email = $1', [email]);
}

module.exports = {
  MAX_ATTEMPTS,
  create,
  findLatestUnverifiedByEmail,
  findLatestVerifiedByEmail,
  markVerified,
  incrementAttempts,
  deleteByEmail,
};
