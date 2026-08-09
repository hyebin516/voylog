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
      `INSERT INTO places (video_id, name, address, latitude, longitude, timestamp_sec, source, confidence, category, business_hours, business_hours_is_estimated, tags)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
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
      ]
    );
    inserted.push(rows[0]);
  }
  return inserted;
}

module.exports = { findByUrl, findPlacesByVideoId, createVideo, createPlaces };
