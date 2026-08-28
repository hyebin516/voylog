const pool = require('../config/db');

async function create(userId, course) {
  const { rows } = await pool.query(
    `INSERT INTO saved_walking_courses (user_id, region, route_type, transport_mode, total_distance_m, total_duration_sec, route_data)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      userId,
      course.region,
      course.routeType,
      course.transportMode,
      course.totalDistanceM,
      course.totalDurationSec,
      JSON.stringify(course.routeData),
    ]
  );
  return rows[0];
}

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    'SELECT * FROM saved_walking_courses WHERE user_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC',
    [userId]
  );
  return rows;
}

async function findById(savedCourseId) {
  const { rows } = await pool.query(
    'SELECT * FROM saved_walking_courses WHERE saved_course_id = $1 AND deleted_at IS NULL',
    [savedCourseId]
  );
  return rows[0] || null;
}

async function softDelete(savedCourseId) {
  await pool.query('UPDATE saved_walking_courses SET deleted_at = now() WHERE saved_course_id = $1', [savedCourseId]);
}

module.exports = { create, findAllByUser, findById, softDelete };
