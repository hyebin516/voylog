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

/**
 * Bookmarked places across a given set of users (e.g. "users with similar
 * taste"), tagged with which user bookmarked each one so the caller can
 * attribute a signal per bookmarker. excludePlaceIds filters out places the
 * requester has already bookmarked or hidden -- there's no point
 * recommending those back.
 */
async function findByUsers(userIds, excludePlaceIds = []) {
  if (userIds.length === 0) return [];
  const { rows } = await pool.query(
    `SELECT b.user_id, p.*
     FROM bookmarks b
     JOIN places p ON p.place_id = b.place_id
     WHERE b.user_id = ANY($1::uuid[]) AND p.deleted_at IS NULL
       AND NOT (p.place_id = ANY($2::uuid[]))`,
    [userIds, excludePlaceIds]
  );
  return rows;
}

module.exports = { findByUserAndPlace, create, findAllByUser, findById, remove, findByUsers };
