const crypto = require('crypto');
const pool = require('../config/db');
const redis = require('../config/redis');
const videoRepository = require('../repositories/video.repository');
const placeEmbeddingRepository = require('../repositories/place-embedding.repository');
const { callAiWorker } = require('./aiWorkerClient');
const { extractYoutubeVideoId } = require('../utils/youtube');

const CACHE_TTL_SECONDS = 60 * 60 * 24 * 7;

function buildEmbeddingText(place) {
  return [place.name, place.category, place.address].filter(Boolean).join(' | ');
}

/**
 * Best-effort: a place that fails to embed just falls back to
 * non-personalized scoring later, so no failure here should ever surface
 * to the caller of analyzeVideo.
 */
async function generateAndStorePlaceEmbeddings(places) {
  await Promise.all(
    places
      .filter((place) => place.latitude != null && place.longitude != null)
      .map(async (place) => {
        try {
          const text = buildEmbeddingText(place);
          const result = await callAiWorker('/embeddings/generate', { text }, 15000);
          const sourceTextHash = crypto.createHash('sha256').update(text).digest('hex');
          await placeEmbeddingRepository.upsert(place.place_id, {
            embedding: result.embedding,
            model: result.model,
            dimensions: result.dimensions,
            sourceTextHash,
          });
        } catch (err) {
          // no-op: embedding is an enhancement, not a requirement
        }
      })
  );
}

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
      category: p.category,
      businessHours: p.business_hours,
      businessHoursIsEstimated: Boolean(p.business_hours_is_estimated),
      tags: p.tags || [],
      mentionNote: p.mention_note,
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

  await generateAndStorePlaceEmbeddings(savedPlaces);

  const response = toResponse(savedVideo, savedPlaces, false);
  await redis.set(cacheKey, JSON.stringify(response), 'EX', CACHE_TTL_SECONDS);
  return response;
}

async function searchByHashtag(hashtag) {
  const result = await callAiWorker('/search-hashtag', { hashtag }, 10000);
  return { videos: result.videos };
}

function buildRecommendationQuery(regions, themes, duration) {
  return [...regions, ...themes, duration, '브이로그'].join(' ');
}

async function getRecommendations(regions, themes, duration) {
  const query = buildRecommendationQuery(regions, themes, duration);
  const result = await callAiWorker('/search-videos', { query }, 10000);
  return { videos: result.videos };
}

module.exports = { analyzeVideo, searchByHashtag, getRecommendations, generateAndStorePlaceEmbeddings };
