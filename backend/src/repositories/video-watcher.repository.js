const pool = require('../config/db');

/**
 * Remembers that this user asked for the video's analysis, so the
 * background enrichment can tell them when it adds places. Analysing does
 * not require a login, so this is only called when the request had one.
 */
async function add(userId, videoId) {
  await pool.query(
    `INSERT INTO video_analysis_watchers (user_id, video_id)
     VALUES ($1, $2)
     ON CONFLICT (user_id, video_id) DO NOTHING`,
    [userId, videoId]
  );
}

async function findUserIdsByVideo(videoId) {
  const { rows } = await pool.query('SELECT user_id FROM video_analysis_watchers WHERE video_id = $1', [videoId]);
  return rows.map((row) => row.user_id);
}

/** Once told, a watcher has no reason to be told again. */
async function removeByVideo(videoId) {
  await pool.query('DELETE FROM video_analysis_watchers WHERE video_id = $1', [videoId]);
}

module.exports = { add, findUserIdsByVideo, removeByVideo };
