const pool = require('../config/db');

async function create(userId, tripId, dayNumber, startHotelId, endHotelId, optimizedResult) {
  const { rows } = await pool.query(
    `INSERT INTO itineraries (user_id, trip_id, day_number, start_hotel_id, end_hotel_id, route_type, optimization_priority, transport_mode, total_distance_m, total_duration_sec, route_data)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING *`,
    [
      userId,
      tripId,
      dayNumber,
      startHotelId,
      endHotelId,
      optimizedResult.routeType,
      optimizedResult.optimizationPriority,
      optimizedResult.transportMode,
      optimizedResult.totalDistanceM,
      optimizedResult.totalDurationSec,
      JSON.stringify(optimizedResult.optimizedRoute),
    ]
  );
  return rows[0];
}

async function findAllByTrip(tripId) {
  const { rows } = await pool.query(
    'SELECT * FROM itineraries WHERE trip_id = $1 AND deleted_at IS NULL ORDER BY day_number ASC',
    [tripId]
  );
  return rows;
}

async function findByTripAndDay(tripId, dayNumber) {
  const { rows } = await pool.query(
    'SELECT * FROM itineraries WHERE trip_id = $1 AND day_number = $2 AND deleted_at IS NULL',
    [tripId, dayNumber]
  );
  return rows[0] || null;
}

async function findById(itineraryId) {
  const { rows } = await pool.query('SELECT * FROM itineraries WHERE itinerary_id = $1 AND deleted_at IS NULL', [
    itineraryId,
  ]);
  return rows[0] || null;
}

/**
 * Soft-deletes one day of a trip and moves the later days up by one, in one
 * transaction, so a trip's days stay 1..N.
 *
 * Without the renumbering, deleting 1일차 of two left only "2일차", and the
 * app's 날짜 추가 (which asks for day count + 1) then hit DAY_EXISTS.
 *
 * The shift goes through +1000 first: `uq_itineraries_trip_day` is checked
 * row by row, so moving 3→2 while 2 still exists would fail mid-statement,
 * and day_number must stay > 0 (CHECK), which rules out a negative detour.
 */
async function softDeleteDayAndRenumber(itineraryId, tripId, dayNumber) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'UPDATE itineraries SET deleted_at = now(), updated_at = now() WHERE itinerary_id = $1 AND deleted_at IS NULL',
      [itineraryId]
    );
    await client.query(
      'UPDATE itineraries SET day_number = day_number + 1000 WHERE trip_id = $1 AND day_number > $2 AND deleted_at IS NULL',
      [tripId, dayNumber]
    );
    await client.query(
      'UPDATE itineraries SET day_number = day_number - 1001, updated_at = now() WHERE trip_id = $1 AND day_number > 1000 AND deleted_at IS NULL',
      [tripId]
    );
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { create, findAllByTrip, findByTripAndDay, findById, softDeleteDayAndRenumber };
