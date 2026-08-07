const pool = require('../config/db');

/**
 * Candidate places within radiusMeters of (latitude, longitude), nearest
 * first. Distance is computed with the standard spherical-law-of-cosines
 * formula (no PostGIS/earthdistance extension required).
 */
async function findNearby(latitude, longitude, radiusMeters, limit) {
  const { rows } = await pool.query(
    `SELECT * FROM (
       SELECT p.*,
         6371000 * acos(
           LEAST(1, GREATEST(-1,
             cos(radians($1)) * cos(radians(p.latitude)) * cos(radians(p.longitude) - radians($2))
             + sin(radians($1)) * sin(radians(p.latitude))
           ))
         ) AS distance_m
       FROM places p
       WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL AND p.deleted_at IS NULL
     ) sub
     WHERE distance_m <= $3
     ORDER BY distance_m
     LIMIT $4`,
    [latitude, longitude, radiusMeters, limit]
  );
  return rows;
}

module.exports = { findNearby };
