const pool = require('../config/db');

async function create(userId, tripId, dayNumber, startHotelId, endHotelId, optimizedResult) {
  const { rows } = await pool.query(
    `INSERT INTO itineraries (user_id, trip_id, day_number, start_hotel_id, end_hotel_id, route_type, optimization_priority, total_distance_m, total_duration_sec, route_data)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      userId,
      tripId,
      dayNumber,
      startHotelId,
      endHotelId,
      optimizedResult.routeType,
      optimizedResult.optimizationPriority,
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

module.exports = { create, findAllByTrip, findByTripAndDay };
