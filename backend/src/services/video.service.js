const crypto = require('crypto');
const pool = require('../config/db');
const redis = require('../config/redis');
const videoRepository = require('../repositories/video.repository');
const placeEmbeddingRepository = require('../repositories/place-embedding.repository');
const videoWatcherRepository = require('../repositories/video-watcher.repository');
const pushService = require('./push.service');
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

// Downloading and reading a whole video takes minutes (measured 2m07s for a
// 13-minute vlog, 3m01s for a 25-minute one), so this job gets a budget
// nothing else in the app would tolerate. It never blocks a request. Five
// minutes also matches how long the app keeps checking for the result
// (20s x 15) -- a job still running after that would finish unseen.
const ENRICHMENT_TIMEOUT_MS = 300000;

// The first pass runs while the user waits. gpt-4.1-mini (FR-01 place
// extraction) takes 23-28s on a 25-minute vlog -- 30s left no room at all.
const FIRST_PASS_EXTRACTION_TIMEOUT_MS = 60000;

// Videos currently being enriched in this process, so a burst of analyze
// calls for the same video can't start the (expensive) job more than once.
const enrichmentsInFlight = new Set();

function placeKey(place) {
  return (place.name || '').trim().toLowerCase();
}

// Two extractions of the same video mention a place within a few seconds of
// each other. Used with a matching category, since one scene can name two
// different places.
const SAME_MENTION_MAX_SECONDS = 5;

/**
 * The saved place an enrichment result is another take on: the same name,
 * or the same moment of the video. The second case matters because the
 * on-screen-text pass often finds the real spelling of a name the captions
 * misheard ("소배" -> "소베"), and without it the corrected place was added
 * as a second, duplicate card while the misheard one stayed unlocated.
 */
function findSavedMatch(savedPlaces, place, alreadyMatched) {
  const key = placeKey(place);
  return savedPlaces.find(
    (saved) =>
      !alreadyMatched.has(saved.place_id) &&
      (placeKey(saved) === key ||
        (place.timestampSec != null &&
          saved.timestamp_sec != null &&
          Math.abs(saved.timestamp_sec - place.timestampSec) <= SAME_MENTION_MAX_SECONDS &&
          (saved.category || null) === (place.category || null)))
  );
}

/// Re-runs extraction with the on-screen-text pass and adds any places the
/// text-only pass missed. Fire-and-forget: failures only mean the video
/**
 * Tells everyone who asked for this video's analysis that the background
 * pass is done (FR-12). Best effort in both directions: a failure here must
 * not mark a finished enrichment as failed, and nobody is told twice.
 */
async function notifyWatchers(video, addedPlaceCount) {
  try {
    const userIds = await videoWatcherRepository.findUserIdsByVideo(video.video_id);
    if (userIds.length === 0) return;

    const body =
      addedPlaceCount > 0
        ? `"${video.title}"에서 장소 ${addedPlaceCount}곳을 더 찾았어요.`
        : `"${video.title}" 추가 분석이 끝났어요.`;

    await Promise.all(
      userIds.map((userId) =>
        pushService.sendToUser(userId, {
          kind: 'analysisComplete',
          title: '영상 분석이 끝났어요',
          body,
          data: { videoId: video.video_id, youtubeVideoId: extractYoutubeVideoId(video.youtube_url) },
        })
      )
    );
    await videoWatcherRepository.removeByVideo(video.video_id);
  } catch (err) {
    console.warn(`Notifying watchers of video ${video.video_id} failed: ${err.message}`);
  }
}

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
        transcriptAutoGenerated: Boolean(transcript.captionsAutoGenerated),
        llmProvider: 'auto',
        forceScreenText: true,
      },
      ENRICHMENT_TIMEOUT_MS
    );

    const matched = new Set();
    const newPlaces = [];
    const locatedPlaces = [];
    for (const place of result.places || []) {
      const saved = findSavedMatch(existingPlaces, place, matched);
      if (!saved) {
        newPlaces.push(place);
        continue;
      }
      matched.add(saved.place_id);
      // Only fill in a place the first pass couldn't locate; one that
      // already has a location is left as the user first saw it.
      if (saved.latitude == null && place.latitude != null) {
        locatedPlaces.push({ saved, place });
      }
    }

    if (newPlaces.length > 0 || locatedPlaces.length > 0) {
      const client = await pool.connect();
      let changedPlaces;
      try {
        await client.query('BEGIN');
        const created = newPlaces.length > 0 ? await videoRepository.createPlaces(client, video.video_id, newPlaces) : [];
        const located = [];
        for (const { saved, place } of locatedPlaces) {
          // eslint-disable-next-line no-await-in-loop
          located.push(await videoRepository.locatePlace(client, saved.place_id, place));
        }
        changedPlaces = [...created, ...located];
        await client.query('COMMIT');
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
      await generateAndStorePlaceEmbeddings(changedPlaces);
    }

    await videoRepository.setEnrichmentStatus(video.video_id, 'done');
    // The cached response still holds the pre-enrichment place list.
    await cacheDelete(`video:${extractYoutubeVideoId(video.youtube_url)}`);
    await notifyWatchers(video, newPlaces.length + locatedPlaces.length);
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

async function runAnalysis(rawYoutubeUrl) {
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
      transcriptAutoGenerated: Boolean(transcript.captionsAutoGenerated),
      llmProvider: 'auto',
    },
    FIRST_PASS_EXTRACTION_TIMEOUT_MS
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

/**
 * [watcherUserId] is the logged-in caller, if any -- analysis works for
 * guests, so it can be null. They only get remembered while the background
 * pass is still running: there is nothing left to tell them otherwise.
 */
async function analyzeVideo(rawYoutubeUrl, watcherUserId = null) {
  const response = await runAnalysis(rawYoutubeUrl);

  if (watcherUserId && response.enrichmentPending) {
    try {
      await videoWatcherRepository.add(watcherUserId, response.videoId);
    } catch (err) {
      // The analysis itself succeeded; not being notified is the whole cost.
      console.warn(`Could not register push watcher for video ${response.videoId}: ${err.message}`);
    }
  }

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
