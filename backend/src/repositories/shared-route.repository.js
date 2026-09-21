const pool = require('../config/db');

async function create(userId, route) {
  const { rows } = await pool.query(
    `INSERT INTO shared_routes (user_id, source_type, source_id, title, transport_mode, total_distance_m, total_duration_sec, place_count, route_data)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [
      userId,
      route.sourceType,
      route.sourceId,
      route.title,
      route.transportMode,
      route.totalDistanceM,
      route.totalDurationSec,
      route.placeCount,
      JSON.stringify(route.routeData),
    ]
  );
  return rows[0];
}

async function findById(sharedRouteId) {
  const { rows } = await pool.query('SELECT * FROM shared_routes WHERE shared_route_id = $1 AND deleted_at IS NULL', [
    sharedRouteId,
  ]);
  return rows[0] || null;
}

async function updateTitle(sharedRouteId, title) {
  const { rows } = await pool.query(
    'UPDATE shared_routes SET title = $2, updated_at = now() WHERE shared_route_id = $1 RETURNING *',
    [sharedRouteId, title]
  );
  return rows[0];
}

async function softDelete(sharedRouteId) {
  await pool.query('UPDATE shared_routes SET deleted_at = now() WHERE shared_route_id = $1', [sharedRouteId]);
}

// Publishing is otherwise not idempotent (each call inserts a fresh row) --
// this lets the publish services refuse a second publish of the same
// saved-walking-course/itinerary instead of silently piling up duplicates.
async function findActiveBySource(userId, sourceType, sourceId) {
  const { rows } = await pool.query(
    'SELECT * FROM shared_routes WHERE user_id = $1 AND source_type = $2 AND source_id = $3 AND deleted_at IS NULL',
    [userId, sourceType, sourceId]
  );
  return rows[0] || null;
}

// Includes the viewer's own posts (unlike an earlier version of this feed --
// the user explicitly asked to see and manage their own published routes
// from the same feed, not a separate screen). `viewerUserId`, when present,
// drives both `liked_by_me` and `is_owner` -- it's always the same user for
// both purposes so a single param does double duty.
async function findFeed({ viewerUserId, limit }) {
  const params = [limit];
  let likedByMeSelect = 'false AS liked_by_me';
  let isOwnerSelect = 'false AS is_owner';

  if (viewerUserId) {
    params.push(viewerUserId);
    const idx = params.length;
    likedByMeSelect = `EXISTS (
      SELECT 1 FROM route_likes rl2 WHERE rl2.shared_route_id = sr.shared_route_id AND rl2.user_id = $${idx}
    ) AS liked_by_me`;
    isOwnerSelect = `(sr.user_id = $${idx}) AS is_owner`;
  }

  const { rows } = await pool.query(
    `SELECT sr.*, u.nickname AS author_nickname,
            COUNT(rl.user_id)::int AS like_count,
            ${likedByMeSelect},
            ${isOwnerSelect}
     FROM shared_routes sr
     JOIN users u ON u.user_id = sr.user_id
     LEFT JOIN route_likes rl ON rl.shared_route_id = sr.shared_route_id
     WHERE sr.deleted_at IS NULL
     GROUP BY sr.shared_route_id, u.nickname
     ORDER BY sr.created_at DESC
     LIMIT $1`,
    params
  );
  return rows;
}

async function findAllActive() {
  const { rows } = await pool.query('SELECT * FROM shared_routes WHERE deleted_at IS NULL ORDER BY created_at');
  return rows;
}

async function updateRouteData(sharedRouteId, routeData) {
  await pool.query('UPDATE shared_routes SET route_data = $2, updated_at = now() WHERE shared_route_id = $1', [
    sharedRouteId,
    JSON.stringify(routeData),
  ]);
}

module.exports = {
  create,
  findById,
  updateTitle,
  softDelete,
  findFeed,
  findActiveBySource,
  findAllActive,
  updateRouteData,
};
