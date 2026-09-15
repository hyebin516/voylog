const crypto = require('crypto');
const pool = require('../config/db');
const redis = require('../config/redis');
const videoRepository = require('../repositories/video.repository');
const placeEmbeddingRepository = require('../repositories/place-embedding.repository');
const { callAiWorker } = require('./aiWorkerClient');
const { extractYoutubeVideoId, normalizeYoutubeUrl } = require('../utils/youtube');
const { buildPlaceEmbeddingText } = require('../utils/place-embedding-text');

const CACHE_TTL_SECONDS = 60 * 60 * 24 * 7;

// Best-effort cache reads/writes -- per CLAUDE.md's caching strategy, Redis
// only ever accelerates the PostgreSQL/AI-Worker lookup below, it's never
// the source of truth. A Redis outage must fall through to that lookup
// instead of failing the whole analyze request.
async function cacheGet(key) {
  try {
    return await redis.get(key);
  } catch (err) {
    return null;
  }
}

async function cacheSet(key, value) {
  try {
    await redis.set(key, value, 'EX', CACHE_TTL_SECONDS);
  } catch (err) {
    // ignore -- caching is best-effort
  }
}

async function cacheDelete(key) {
  try {
    await redis.del(key);
  } catch (err) {
    // ignore -- caching is best-effort
  }
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
          const text = buildPlaceEmbeddingText(place);
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
    youtubeVideoId: extractYoutubeVideoId(video.youtube_url),
    title: video.title,
    isCached,
    // True while the background on-screen-text pass is still running, so
    // the client knows more places may still appear and can refresh.
    enrichmentPending: video.enrichment_status === 'pending',
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

// Downloading and reading a whole video takes minutes, so this job gets a
// budget nothing else in the app would tolerate. It never blocks a request.
const ENRICHMENT_TIMEOUT_MS = 600000;

// Videos currently being enriched in this process, so a burst of analyze
// calls for the same video can't start the (expensive) job more than once.
const enrichmentsInFlight = new Set();

function placeKey(place) {
  return (place.name || '').trim().toLowerCase();
}

/// Re-runs extraction with the on-screen-text pass and adds any places the
/// text-only pass missed. Fire-and-forget: failures only mean the video
/// keeps the places it already had. [transcript] is re-fetched when the
/// caller doesn't already have it (an older video being caught up).
async function enrichWithScreenText(video, existingPlaces, transcript) {
  if (enrichmentsInFlight.has(video.video_id)) return;
  enrichmentsInFlight.add(video.video_id);

  try {
    await videoRepository.setEnrichmentStatus(video.video_id, 'pending');
    if (!transcript) {
      transcript = await callAiWorker('/extract-transcript', { youtubeUrl: video.youtube_url }, 30000);
    }

    const result = await callAiWorker(
      '/extract-places',
      {
        video: {
          videoId: extractYoutubeVideoId(video.youtube_url),
          youtubeUrl: video.youtube_url,
          title: transcript.title,
          description: transcript.description,
          hashtags: transcript.hashtags || [],
        },
        transcript: transcript.segments,
        llmProvider: 'auto',
        forceScreenText: true,
      },
      ENRICHMENT_TIMEOUT_MS
    );

    const known = new Set(existingPlaces.map(placeKey));
    const newPlaces = (result.places || []).filter((p) => !known.has(placeKey(p)));

    if (newPlaces.length > 0) {
      const client = await pool.connect();
      let savedPlaces;
      try {
        await client.query('BEGIN');
        savedPlaces = await videoRepository.createPlaces(client, video.video_id, newPlaces);
        await client.query('COMMIT');
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
      await generateAndStorePlaceEmbeddings(savedPlaces);
    }

    await videoRepository.setEnrichmentStatus(video.video_id, 'done');
    // The cached response still holds the pre-enrichment place list.
    await cacheDelete(`video:${extractYoutubeVideoId(video.youtube_url)}`);
  } catch (err) {
    try {
      await videoRepository.setEnrichmentStatus(video.video_id, 'failed');
    } catch (statusErr) {
      // The job already failed; failing to record that changes nothing.
    }
    console.warn(`Screen-text enrichment failed for video ${video.video_id}: ${err.message}`);
  } finally {
    enrichmentsInFlight.delete(video.video_id);
  }
}

async function analyzeVideo(rawYoutubeUrl) {
  const youtubeUrl = normalizeYoutubeUrl(rawYoutubeUrl);
  const youtubeVideoId = extractYoutubeVideoId(youtubeUrl);
  const cacheKey = `video:${youtubeVideoId}`;

  const cached = await cacheGet(cacheKey);
  if (cached) {
    return { ...JSON.parse(cached), isCached: true };
  }

  const existingVideo = await videoRepository.findByUrl(youtubeUrl);
  if (existingVideo && existingVideo.is_analyzed) {
    const places = await videoRepository.findPlacesByVideoId(existingVideo.video_id);

    // Videos analyzed before every analysis was enriched never got the
    // on-screen-text pass. Opening one again catches it up, in the
    // background like a fresh analysis.
    const neverEnriched = existingVideo.enrichment_status == null;
    if (neverEnriched) {
      existingVideo.enrichment_status = 'pending';
      enrichWithScreenText(existingVideo, places);
    }

    const response = toResponse(existingVideo, places, true);
    // Not cached while enrichment is pending: the entry would pin
    // enrichmentPending=true, and the job clears the key when it finishes
    // anyway.
    if (!neverEnriched) await cacheSet(cacheKey, JSON.stringify(response));
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

  // Every fresh analysis also gets the on-screen-text pass. It used to run
  // only when the text pass found fewer than 5 places, but a video can
  // yield 10 places from its transcript and still show more only as
  // overlays -- users noticed missing places on exactly those videos. It
  // takes minutes, so the user gets what we have now and the rest arrives
  // later; results are cached per video, so each video pays this once.
  savedVideo.enrichment_status = 'pending';
  // Deliberately not awaited: this request must not wait on it.
  enrichWithScreenText(savedVideo, savedPlaces, transcript);

  const response = toResponse(savedVideo, savedPlaces, false);
  // A pending enrichment will replace this entry when it finishes, so
  // caching it now is safe -- the job deletes the key on completion.
  await cacheSet(cacheKey, JSON.stringify(response));
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
