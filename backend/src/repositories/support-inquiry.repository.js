const pool = require('../config/db');

async function create({ userId, email, category, message }) {
  const { rows } = await pool.query(
    `INSERT INTO support_inquiries (user_id, email, category, message)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [userId ?? null, email, category, message]
  );
  return rows[0];
}

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    `SELECT * FROM support_inquiries
      WHERE user_id = $1 AND deleted_at IS NULL
      ORDER BY created_at DESC`,
    [userId]
  );
  return rows;
}

module.exports = { create, findAllByUser };
