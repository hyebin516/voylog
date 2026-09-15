function extractYoutubeVideoId(youtubeUrl) {
  const match = youtubeUrl.match(/(?:v=|youtu\.be\/)([\w-]{11})/);
  return match ? match[1] : null;
}

/**
 * Canonical form of a YouTube URL, keyed only on the video id -- drops
 * every query param, including `si=`, the share-tracking token YouTube
 * generates fresh and random each time a link is shared/copied via the
 * "Share" button. Without this, `videos.youtube_url` lookups/uniqueness
 * treated re-shared links to the same video as a brand new video: a fresh
 * (non-cached, non-deterministic) LLM extraction on every re-paste instead
 * of ever hitting the DB/Redis cache for a video already analyzed.
 */
function normalizeYoutubeUrl(youtubeUrl) {
  const videoId = extractYoutubeVideoId(youtubeUrl);
  return videoId ? `https://www.youtube.com/watch?v=${videoId}` : youtubeUrl;
}

module.exports = { extractYoutubeVideoId, normalizeYoutubeUrl };
