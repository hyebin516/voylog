const pool = require('../config/db');

async function like(userId, sharedRouteId) {
  await pool.query(
    `INSERT INTO route_likes (user_id, shared_route_id) VALUES ($1, $2)
     ON CONFLICT (user_id, shared_route_id) DO NOTHING`,
    [userId, sharedRouteId]
  );
}

async function unlike(userId, sharedRouteId) {
  await pool.query('DELETE FROM route_likes WHERE user_id = $1 AND shared_route_id = $2', [userId, sharedRouteId]);
}

module.exports = { like, unlike };
