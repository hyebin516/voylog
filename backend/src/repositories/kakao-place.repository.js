const pool = require('../config/db');

const SOURCE = 'kakao_local';

/**
 * Writes places found through Kakao's keyword search into `places` so they
 * can be bookmarked, added to folders and learned from like any other place.
 *
 * Keyed on `(source, external_id)` -- the same unique index the public
 * datasets use -- so saving or publishing the same course twice updates the
 * one row instead of adding a second copy of the cafe. Returns a map from
 * each place's Kakao id to its `places.place_id`.
 */
async function upsertAll(places) {
  if (places.length === 0) return new Map();

  const values = [];
  const placeholders = places.map((place, i) => {
    const o = i * 6;
    values.push(place.externalId, place.name, place.address, place.latitude, place.longitude, place.category);
    return `($${o + 1}, $${o + 2}, $${o + 3}, $${o + 4}, $${o + 5}, $${o + 6})`;
  });

  // `confidence` is 1: the user kept a course containing this place, and the
  // name and coordinates came from Kakao rather than from a language model.
  const { rows } = await pool.query(
    `INSERT INTO places (source, external_id, name, address, latitude, longitude, category, confidence)
     SELECT '${SOURCE}', v.external_id::varchar, v.name::varchar, v.address::varchar,
            v.latitude::numeric, v.longitude::numeric, v.category::varchar, 1
     FROM (VALUES ${placeholders.join(', ')})
       AS v(external_id, name, address, latitude, longitude, category)
     ON CONFLICT (source, external_id) WHERE external_id IS NOT NULL DO UPDATE
       SET name = EXCLUDED.name,
           address = COALESCE(EXCLUDED.address, places.address),
           latitude = EXCLUDED.latitude,
           longitude = EXCLUDED.longitude,
           category = COALESCE(EXCLUDED.category, places.category),
           deleted_at = NULL,
           updated_at = now()
     RETURNING place_id, external_id`,
    values
  );

  return new Map(rows.map((r) => [r.external_id, r.place_id]));
}

module.exports = { upsertAll, SOURCE };
