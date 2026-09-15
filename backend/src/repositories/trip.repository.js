const pool = require('../config/db');

async function create(userId, name, startDate, endDate) {
  const { rows } = await pool.query(
    `INSERT INTO trips (user_id, name, start_date, end_date) VALUES ($1, $2, $3, $4) RETURNING *`,
    [userId, name, startDate ?? null, endDate ?? null]
  );
  return rows[0];
}

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    'SELECT * FROM trips WHERE user_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC',
    [userId]
  );
  return rows;
}

async function findById(tripId) {
  const { rows } = await pool.query('SELECT * FROM trips WHERE trip_id = $1 AND deleted_at IS NULL', [tripId]);
  return rows[0] || null;
}

async function countDaysByTrip(tripId) {
  const { rows } = await pool.query(
    'SELECT count(*)::int AS count FROM itineraries WHERE trip_id = $1 AND deleted_at IS NULL',
    [tripId]
  );
  return rows[0].count;
}

async function softDelete(tripId) {
  await pool.query('UPDATE trips SET deleted_at = now() WHERE trip_id = $1', [tripId]);
  await pool.query('UPDATE itineraries SET deleted_at = now() WHERE trip_id = $1', [tripId]);
}

async function updateDates(tripId, startDate, endDate) {
  const { rows } = await pool.query(
    `UPDATE trips SET start_date = $2, end_date = $3, updated_at = now() WHERE trip_id = $1 RETURNING *`,
    [tripId, startDate, endDate]
  );
  return rows[0];
}

module.exports = { create, findAllByUser, findById, countDaysByTrip, softDelete, updateDates };
