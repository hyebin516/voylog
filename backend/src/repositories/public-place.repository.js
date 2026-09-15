const pool = require('../config/db');

/**
 * Writes for places bulk-loaded from public datasets (FR-15/FR-17 cold
 * start, migration 025). Only the importer scripts use this.
 */

// 8 parameters per row; PostgreSQL allows 65535 per statement.
const MAX_ROWS_PER_STATEMENT = 1000;

/**
 * Inserts dataset places, or refreshes the ones a previous import already
 * created (matched on source + external_id). A refresh never touches
 * deleted_at, so a place removed as a duplicate stays removed.
 *
 * @returns {Promise<number>} rows inserted or updated
 */
async function upsertMany(places) {
  let written = 0;
  for (let start = 0; start < places.length; start += MAX_ROWS_PER_STATEMENT) {
    const batch = places.slice(start, start + MAX_ROWS_PER_STATEMENT);
    const values = [];
    const placeholders = batch.map((place, i) => {
      const offset = i * 8;
      values.push(
        place.source,
        place.externalId,
        place.name,
        place.address,
        place.latitude,
        place.longitude,
        place.category,
        JSON.stringify(place.tags)
      );
      return `($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4}, $${offset + 5}, $${offset + 6}, $${offset + 7}, $${offset + 8}::jsonb, 1)`;
    });

    // eslint-disable-next-line no-await-in-loop
    const { rowCount } = await pool.query(
      `INSERT INTO places (source, external_id, name, address, latitude, longitude, category, tags, confidence)
       VALUES ${placeholders.join(', ')}
       ON CONFLICT (source, external_id) WHERE external_id IS NOT NULL DO UPDATE
         SET name = EXCLUDED.name,
             address = EXCLUDED.address,
             latitude = EXCLUDED.latitude,
             longitude = EXCLUDED.longitude,
             category = EXCLUDED.category,
             tags = EXCLUDED.tags,
             updated_at = now()`,
      values
    );
    written += rowCount;
  }
  return written;
}

/**
 * The same shop often appears in both datasets, or was already found in a
 * video -- and a nearby list showing "OO카페" twice looks broken. A dataset
 * place is removed (soft delete) when a video place or a higher-priority
 * dataset place with the same normalized name sits within ~50m.
 *
 * Priority: video places > tour_api > semas. Video places carry the vlog
 * context (timestamp, mention note) and TourAPI entries are curated, so the
 * bulk store listing is the one to drop. Places someone has bookmarked are
 * never removed.
 *
 * @returns {Promise<number>} places removed
 */
async function removeDuplicateDatasetPlaces() {
  const { rowCount } = await pool.query(
    `WITH candidates AS (
       SELECT place_id, source, latitude, longitude,
              regexp_replace(lower(name), '[^가-힣a-z0-9]', '', 'g') AS normalized_name,
              CASE WHEN external_id IS NULL THEN 0 WHEN source = 'tour_api' THEN 1 ELSE 2 END AS priority
       FROM places
       WHERE deleted_at IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL
     )
     UPDATE places p
     SET deleted_at = now(), updated_at = now()
     FROM candidates dup
     WHERE p.place_id = dup.place_id
       AND dup.priority > 0
       AND dup.normalized_name <> ''
       AND NOT EXISTS (SELECT 1 FROM bookmarks b WHERE b.place_id = dup.place_id)
       AND EXISTS (
         SELECT 1 FROM candidates keep
         WHERE keep.priority < dup.priority
           AND keep.normalized_name = dup.normalized_name
           AND keep.latitude BETWEEN dup.latitude - 0.00045 AND dup.latitude + 0.00045
           AND keep.longitude BETWEEN dup.longitude - 0.00057 AND dup.longitude + 0.00057
       )`
  );
  return rowCount;
}

/**
 * Dataset places whose names could be cut off: anything containing a
 * bracket or connector, and 상가정보 names ending in a one-syllable word
 * (where the importer appended a 지점명). A cheap SQL prefilter only -- the
 * caller decides with isBrokenPlaceName / isBrokenBranchName.
 */
async function findDatasetPlacesWithSuspectNames() {
  const { rows } = await pool.query(
    `SELECT place_id, source, name FROM places
     WHERE deleted_at IS NULL AND external_id IS NOT NULL
       AND (name ~ '[][()&·,/]' OR (source = 'semas' AND name ~ ' [가-힣]$'))`
  );
  return rows;
}

/**
 * Soft-deletes dataset places. Never touches a video place, or a place
 * someone has bookmarked.
 *
 * @returns {Promise<number>} places removed
 */
async function removeDatasetPlaces(placeIds) {
  if (placeIds.length === 0) return 0;
  const { rowCount } = await pool.query(
    `UPDATE places p SET deleted_at = now(), updated_at = now()
     WHERE p.place_id = ANY($1::uuid[])
       AND p.external_id IS NOT NULL AND p.deleted_at IS NULL
       AND NOT EXISTS (SELECT 1 FROM bookmarks b WHERE b.place_id = p.place_id)`,
    [placeIds]
  );
  return rowCount;
}

module.exports = {
  upsertMany,
  removeDuplicateDatasetPlaces,
  findDatasetPlacesWithSuspectNames,
  removeDatasetPlaces,
};
