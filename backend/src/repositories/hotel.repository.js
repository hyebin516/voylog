const pool = require('../config/db');

async function create(userId, hotel) {
  const { rows } = await pool.query(
    `INSERT INTO hotels (user_id, name, address, latitude, longitude)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [userId, hotel.name, hotel.address, hotel.latitude, hotel.longitude]
  );
  return rows[0];
}

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    'SELECT * FROM hotels WHERE user_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC',
    [userId]
  );
  return rows;
}

async function findById(hotelId) {
  const { rows } = await pool.query('SELECT * FROM hotels WHERE hotel_id = $1 AND deleted_at IS NULL', [hotelId]);
  return rows[0] || null;
}

async function update(hotelId, hotel) {
  const { rows } = await pool.query(
    `UPDATE hotels SET name = $1, address = $2, latitude = $3, longitude = $4, updated_at = now()
     WHERE hotel_id = $5
     RETURNING *`,
    [hotel.name, hotel.address, hotel.latitude, hotel.longitude, hotelId]
  );
  return rows[0];
}

async function softDelete(hotelId) {
  await pool.query('UPDATE hotels SET deleted_at = now() WHERE hotel_id = $1', [hotelId]);
}

module.exports = { create, findAllByUser, findById, update, softDelete };
