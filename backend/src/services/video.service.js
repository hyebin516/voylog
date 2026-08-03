const pool = require('../config/db');
const redis = require('../config/redis');
const videoRepository = require('../repositories/video.repository');
const { callAiWorker } = require('./aiWorkerClient');
const { extractYoutubeVideoId } = require('../utils/youtube');

const CACHE_TTL_SECONDS = 60 * 60 * 24 * 7;

function toResponse(video, places, isCached) {
  return {
    videoId: video.video_id,
    title: video.title,
    isCached,
    places: places.map((p) => ({
      placeId: p.place_id,
      name: p.name,
      timestampSec: p.timestamp_sec,
      latitude: p.latitude != null ? Number(p.latitude) : null,
      longitude: p.longitude != null ? Number(p.longitude) : null,
      address: p.address,
      source: p.source,
      confidence: Number(p.confidence),
    })),
  };
}

async function analyzeVideo(youtubeUrl) {
  const youtubeVideoId = extractYoutubeVideoId(youtubeUrl);
  const cacheKey = `video:${youtubeVideoId}`;

  const cached = await redis.get(cacheKey);
  if (cached) {
    return { ...JSON.parse(cached), isCached: true };
  }

  const existingVideo = await videoRepository.findByUrl(youtubeUrl);
  if (existingVideo && existingVideo.is_analyzed) {
    const places = await videoRepository.findPlacesByVideoId(existingVideo.video_id);
    const response = toResponse(existingVideo, places, true);
    await redis.set(cacheKey, JSON.stringify(response), 'EX', CACHE_TTL_SECONDS);
    return response;
  }

  const transcript = await callAiWorker('/extract-transcript', { youtubeUrl }, 30000);

  const placeResult = await callAiWorker(
    '/extract-places',
    {
      video: {
        videoId: youtubeVideoId,
        youtubeUrl,
        title: transcript.title,
        description: transcript.description,
        hashtags: transcript.hashtags || [],
      },
      transcript: transcript.segments,
      llmProvider: 'auto',
    },
    30000
  );

  const client = await pool.connect();
  let savedVideo;
  let savedPlaces;
  try {
    await client.query('BEGIN');
    savedVideo = await videoRepository.createVideo(client, {
      youtubeUrl,
      title: transcript.title,
      description: transcript.description,
      thumbnailUrl: transcript.thumbnailUrl,
      channelName: transcript.channelName,
      publishedAt: transcript.publishedAt,
      durationSec: transcript.durationSec,
      language: transcript.language,
      analysisVersion: 'v1',
    });
    savedPlaces = await videoRepository.createPlaces(client, savedVideo.video_id, placeResult.places);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  const response = toResponse(savedVideo, savedPlaces, false);
  await redis.set(cacheKey, JSON.stringify(response), 'EX', CACHE_TTL_SECONDS);
  return response;
}

async function searchByHashtag(hashtag) {
  const result = await callAiWorker('/search-hashtag', { hashtag }, 10000);
  return { videos: result.videos };
}

module.exports = { analyzeVideo, searchByHashtag };
