const pool = require('../config/db');

/**
 * Candidate places within radiusMeters of (latitude, longitude), nearest
 * first. Distance is computed with the standard spherical-law-of-cosines
 * formula (no PostGIS/earthdistance extension required).
 *
 * excludePlaceIds is a required filter (not a scoring penalty): places the
 * user hid or marked not-interested (phase 5) never come back as candidates
 * at all, regardless of how well they'd otherwise score.
 *
 * bookmarkedOnly restricts candidates to places bookmarked by *any* user
 * (not just the requester) -- used by the region walking-course feature,
 * where the candidate pool is meant to reflect what people have actually
 * found worth saving, not just proximity.
 */
async function findNearby(latitude, longitude, radiusMeters, limit, excludePlaceIds = [], bookmarkedOnly = false) {
  const { rows } = await pool.query(
    `SELECT * FROM (
       SELECT p.*, pe.embedding AS embedding,
         6371000 * acos(
           LEAST(1, GREATEST(-1,
             cos(radians($1)) * cos(radians(p.latitude)) * cos(radians(p.longitude) - radians($2))
             + sin(radians($1)) * sin(radians(p.latitude))
           ))
         ) AS distance_m
       FROM places p
       LEFT JOIN place_embeddings pe ON pe.place_id = p.place_id
       WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL AND p.deleted_at IS NULL
         AND NOT (p.place_id = ANY($5::uuid[]))
         AND ($6 = false OR EXISTS (SELECT 1 FROM bookmarks bk WHERE bk.place_id = p.place_id))
     ) sub
     WHERE distance_m <= $3
     ORDER BY distance_m
     LIMIT $4`,
    [latitude, longitude, radiusMeters, limit, excludePlaceIds, bookmarkedOnly]
  );
  return rows;
}

module.exports = { findNearby };
