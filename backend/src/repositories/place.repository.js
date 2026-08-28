const pool = require('../config/db');

async function findByIds(placeIds) {
  const { rows } = await pool.query(
    'SELECT * FROM places WHERE place_id = ANY($1::uuid[]) AND deleted_at IS NULL',
    [placeIds]
  );
  return rows;
}

async function findById(placeId) {
  const { rows } = await pool.query('SELECT * FROM places WHERE place_id = $1 AND deleted_at IS NULL', [placeId]);
  return rows[0] || null;
}

/**
 * Other place rows (from any video) that sit at essentially the same
 * coordinates as (latitude, longitude) and have a mention_note -- i.e. the
 * same real-world place, mentioned in a different video. Rounds to 4
 * decimal places (~11m) since Kakao geocoding returns the same point for
 * the same real address, so this is enough to cluster same-place mentions
 * without a fuzzy-matching engine. One note per distinct video_id.
 */
async function findSummarySources(latitude, longitude) {
  const { rows } = await pool.query(
    `SELECT video_id, mention_note
     FROM places
     WHERE deleted_at IS NULL
       AND mention_note IS NOT NULL
       AND ROUND(latitude::numeric, 4) = ROUND($1::numeric, 4)
       AND ROUND(longitude::numeric, 4) = ROUND($2::numeric, 4)`,
    [latitude, longitude]
  );

  const noteByVideo = new Map();
  for (const row of rows) {
    if (!noteByVideo.has(row.video_id)) {
      noteByVideo.set(row.video_id, row.mention_note);
    }
  }
  return Array.from(noteByVideo, ([videoId, mentionNote]) => ({ videoId, mentionNote }));
}

async function updateSummary(placeId, { prosSummary, consSummary, summarySourceCount }) {
  await pool.query(
    `UPDATE places
     SET pros_summary = $2, cons_summary = $3, summary_source_count = $4, summary_generated_at = now()
     WHERE place_id = $1`,
    [placeId, prosSummary, consSummary, summarySourceCount]
  );
}

module.exports = { findByIds, findById, findSummarySources, updateSummary };
