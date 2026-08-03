const pool = require('../config/db');

async function create(userId, startHotelId, endHotelId, optimizedResult) {
  const { rows } = await pool.query(
    `INSERT INTO itineraries (user_id, start_hotel_id, end_hotel_id, route_type, optimization_priority, total_distance_m, total_duration_sec, route_data)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      userId,
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

module.exports = { create };
