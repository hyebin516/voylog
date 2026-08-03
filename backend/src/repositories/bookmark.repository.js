const pool = require('../config/db');

async function findByUserAndPlace(userId, placeId) {
  const { rows } = await pool.query('SELECT * FROM bookmarks WHERE user_id = $1 AND place_id = $2', [userId, placeId]);
  return rows[0] || null;
}

async function create(userId, placeId) {
  const { rows } = await pool.query(
    'INSERT INTO bookmarks (user_id, place_id) VALUES ($1, $2) RETURNING *',
    [userId, placeId]
  );
  return rows[0];
}

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    `SELECT b.bookmark_id, b.created_at, p.*
     FROM bookmarks b
     JOIN places p ON p.place_id = b.place_id
     WHERE b.user_id = $1
     ORDER BY b.created_at DESC`,
    [userId]
  );
  return rows;
}

async function findById(bookmarkId) {
  const { rows } = await pool.query('SELECT * FROM bookmarks WHERE bookmark_id = $1', [bookmarkId]);
  return rows[0] || null;
}

async function remove(bookmarkId) {
  await pool.query('DELETE FROM bookmarks WHERE bookmark_id = $1', [bookmarkId]);
}

module.exports = { findByUserAndPlace, create, findAllByUser, findById, remove };
