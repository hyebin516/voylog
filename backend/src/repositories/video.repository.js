const pool = require('../config/db');

async function findByUrl(youtubeUrl) {
  const { rows } = await pool.query('SELECT * FROM videos WHERE youtube_url = $1 AND deleted_at IS NULL', [youtubeUrl]);
  return rows[0] || null;
}

async function findPlacesByVideoId(videoId) {
  const { rows } = await pool.query('SELECT * FROM places WHERE video_id = $1 AND deleted_at IS NULL ORDER BY timestamp_sec NULLS LAST', [videoId]);
  return rows;
}

async function createVideo(client, video) {
  const { rows } = await client.query(
    `INSERT INTO videos (youtube_url, title, description, thumbnail_url, channel_name, published_at, duration_sec, language, is_analyzed, analysis_version)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, $9)
     RETURNING *`,
    [
      video.youtubeUrl,
      video.title,
      video.description,
      video.thumbnailUrl,
      video.channelName,
      video.publishedAt,
      video.durationSec,
      video.language,
      video.analysisVersion,
    ]
  );
  return rows[0];
}

async function createPlaces(client, videoId, places) {
  const inserted = [];
  for (const place of places) {
    const { rows } = await client.query(
      `INSERT INTO places (video_id, name, address, latitude, longitude, timestamp_sec, source, confidence, category, business_hours, business_hours_is_estimated, tags, mention_note)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING *`,
      [
        videoId,
        place.name,
        place.address,
        place.latitude,
        place.longitude,
        place.timestampSec,
        place.source,
        place.confidence,
        place.category || null,
        place.businessHours ? JSON.stringify(place.businessHours) : null,
        Boolean(place.businessHours),
        place.tags && place.tags.length > 0 ? JSON.stringify(place.tags) : null,
        place.mentionNote || null,
      ]
    );
    inserted.push(rows[0]);
  }
  return inserted;
}

/**
 * Gives an already-saved place the name and location a later extraction
 * pass found for it -- the id (and anything that references it, like a
 * bookmark) is kept.
 */
async function locatePlace(client, placeId, { name, address, latitude, longitude }) {
  const { rows } = await client.query(
    `UPDATE places SET name = $2, address = $3, latitude = $4, longitude = $5, updated_at = now()
     WHERE place_id = $1
     RETURNING *`,
    [placeId, name, address, latitude, longitude]
  );
  return rows[0];
}

async function setEnrichmentStatus(videoId, status) {
  await pool.query('UPDATE videos SET enrichment_status = $1, updated_at = now() WHERE video_id = $2', [
    status,
    videoId,
  ]);
}

async function findById(videoId) {
  const { rows } = await pool.query('SELECT * FROM videos WHERE video_id = $1', [videoId]);
  return rows[0] || null;
}

module.exports = {
  findByUrl,
  findById,
  findPlacesByVideoId,
  createVideo,
  createPlaces,
  locatePlace,
  setEnrichmentStatus,
};
