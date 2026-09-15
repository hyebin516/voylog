const pool = require('../config/db');

const METERS_PER_DEGREE_LATITUDE = 111320;

/**
 * Candidate places within radiusMeters of (latitude, longitude). Distance is
 * computed with the standard spherical-law-of-cosines formula (no
 * PostGIS/earthdistance extension required).
 *
 * Rows are first narrowed to a lat/lng bounding box, which
 * idx_places_lat_lng serves. Before public-dataset places (migration 025)
 * this computed a distance for every place in the table, which is fine for
 * a few dozen video places and not for hundreds of thousands.
 *
 * Candidates are taken round-robin across categories -- the nearest place
 * of each category, then the second nearest of each, and so on -- rather
 * than simply nearest first. Store listings are dense enough that the 100
 * nearest places downtown are all restaurants and cafes within a block, and
 * the museum 800m away would never even reach scoring.
 *
 * excludePlaceIds is a required filter (not a scoring penalty): places the
 * user hid or marked not-interested (phase 5) never come back as candidates
 * at all, regardless of how well they'd otherwise score.
 *
 * categories, when given, keeps only places in those categories (the
 * nearby screen's filter tabs).
 *
 * bookmarkedOnly restricts candidates to places bookmarked by *any* user
 * (not just the requester) -- used by the region walking-course feature,
 * where the candidate pool is meant to reflect what people have actually
 * found worth saving, not just proximity.
 */
async function findNearby(
  latitude,
  longitude,
  radiusMeters,
  limit,
  excludePlaceIds = [],
  bookmarkedOnly = false,
  categories = null
) {
  const latitudeDelta = radiusMeters / METERS_PER_DEGREE_LATITUDE;
  const longitudeDelta = radiusMeters / (METERS_PER_DEGREE_LATITUDE * Math.cos((latitude * Math.PI) / 180));

  const { rows } = await pool.query(
    `WITH in_radius AS (
       SELECT * FROM (
         SELECT p.*,
           6371000 * acos(
             LEAST(1, GREATEST(-1,
               cos(radians($1)) * cos(radians(p.latitude)) * cos(radians(p.longitude) - radians($2))
               + sin(radians($1)) * sin(radians(p.latitude))
             ))
           ) AS distance_m
         FROM places p
         WHERE p.latitude IS NOT NULL AND p.deleted_at IS NULL
           AND p.latitude BETWEEN $1::numeric - $7 AND $1::numeric + $7
           AND p.longitude BETWEEN $2::numeric - $8 AND $2::numeric + $8
           AND NOT (p.place_id = ANY($5::uuid[]))
           AND ($6 = false OR EXISTS (SELECT 1 FROM bookmarks bk WHERE bk.place_id = p.place_id))
           AND ($9::text[] IS NULL OR p.category = ANY($9::text[]))
       ) boxed
       WHERE distance_m <= $3
     ),
     picked AS (
       SELECT * FROM (
         SELECT in_radius.*,
           ROW_NUMBER() OVER (PARTITION BY COALESCE(category, '') ORDER BY distance_m) AS category_rank
         FROM in_radius
       ) ranked
       ORDER BY category_rank, distance_m
       LIMIT $4
     )
     SELECT picked.*, pe.embedding AS embedding
     FROM picked
     LEFT JOIN place_embeddings pe ON pe.place_id = picked.place_id
     ORDER BY picked.distance_m`,
    [latitude, longitude, radiusMeters, limit, excludePlaceIds, bookmarkedOnly, latitudeDelta, longitudeDelta, categories]
  );
  return rows;
}

module.exports = { findNearby };
