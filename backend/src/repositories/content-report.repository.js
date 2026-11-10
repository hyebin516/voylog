const pool = require('../config/db');

async function create({ reporterUserId, sharedRouteId, reason, detail }) {
  const { rows } = await pool.query(
    `INSERT INTO content_reports (reporter_user_id, shared_route_id, reason, detail)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [reporterUserId, sharedRouteId, reason, detail ?? null]
  );
  return rows[0];
}

async function findByReporterAndRoute(reporterUserId, sharedRouteId) {
  const { rows } = await pool.query(
    `SELECT * FROM content_reports
      WHERE reporter_user_id = $1 AND shared_route_id = $2 AND deleted_at IS NULL`,
    [reporterUserId, sharedRouteId]
  );
  return rows[0] ?? null;
}

module.exports = { create, findByReporterAndRoute };
