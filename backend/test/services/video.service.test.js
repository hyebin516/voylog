jest.mock('../../src/config/db');
jest.mock('../../src/config/redis');
jest.mock('../../src/repositories/video.repository');
jest.mock('../../src/repositories/place-embedding.repository');
jest.mock('../../src/services/aiWorkerClient');
jest.mock('../../src/repositories/video-watcher.repository');
jest.mock('../../src/services/push.service');

const pool = require('../../src/config/db');
const redis = require('../../src/config/redis');
const videoRepository = require('../../src/repositories/video.repository');
const placeEmbeddingRepository = require('../../src/repositories/place-embedding.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const videoWatcherRepository = require('../../src/repositories/video-watcher.repository');
const pushService = require('../../src/services/push.service');
const {
  analyzeVideo,
  searchByHashtag,
  getRecommendations,
  generateAndStorePlaceEmbeddings,
} = require('../../src/services/video.service');

const YOUTUBE_URL = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

function mockDbClient() {
  const client = { query: jest.fn().mockResolvedValue({ rows: [] }), release: jest.fn() };
  pool.connect = jest.fn().mockResolvedValue(client);
  return client;
}

beforeEach(() => {
  redis.get = jest.fn().mockResolvedValue(null);
  redis.set = jest.fn().mockResolvedValue('OK');
  redis.del = jest.fn().mockResolvedValue(1);
  // The background enrichment job is fire-and-forget, so give its
  // repository calls sane defaults instead of letting them reject.
  videoRepository.setEnrichmentStatus.mockResolvedValue(undefined);
  videoWatcherRepository.add.mockResolvedValue(undefined);
  videoWatcherRepository.findUserIdsByVideo.mockResolvedValue([]);
  videoWatcherRepository.removeByVideo.mockResolvedValue(undefined);
  pushService.sendToUser.mockResolvedValue({ sent: 1 });
});

afterEach(() => jest.clearAllMocks());

describe('analyzeVideo caching (video:{youtubeVideoId} in Redis, DB as source of truth)', () => {
  it('returns the Redis-cached response as isCached:true, without touching the DB or AI worker', async () => {
    redis.get.mockResolvedValue(JSON.stringify({ videoId: 'v1', title: 't', isCached: false, places: [] }));

    const result = await analyzeVideo(YOUTUBE_URL);

    expect(result.isCached).toBe(true);
    expect(videoRepository.findByUrl).not.toHaveBeenCalled();
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('returns an already-analyzed DB row as isCached:true and warms the Redis cache', async () => {
    videoRepository.findByUrl.mockResolvedValue({
      video_id: 'v1',
      youtube_url: YOUTUBE_URL,
      title: 'Existing',
      is_analyzed: true,
      enrichment_status: 'done',
    });
    videoRepository.findPlacesByVideoId.mockResolvedValue([]);

    const result = await analyzeVideo(YOUTUBE_URL);

    expect(result.isCached).toBe(true);
    expect(result.videoId).toBe('v1');
    expect(callAiWorker).not.toHaveBeenCalled();
    expect(redis.set).toHaveBeenCalledWith('video:dQw4w9WgXcQ', expect.any(String), 'EX', expect.any(Number));
  });

  it('runs the full transcript+places pipeline and returns isCached:false for a brand-new video', async () => {
    videoRepository.findByUrl.mockResolvedValue(null);
    callAiWorker
      .mockResolvedValueOnce({ title: 'New video', segments: [{ text: 'hi', timestampSec: 0 }] }) // /extract-transcript
      .mockResolvedValueOnce({ places: [] }); // /extract-places
    const client = mockDbClient();
    client.query.mockImplementation((sql) => {
      if (sql === 'BEGIN' || sql === 'COMMIT') return Promise.resolve();
      return Promise.resolve({ rows: [{ video_id: 'new-id', title: 'New video' }] });
    });
    videoRepository.createVideo.mockResolvedValue({ video_id: 'new-id', youtube_url: YOUTUBE_URL, title: 'New video' });
    videoRepository.createPlaces.mockResolvedValue([
      {
        place_id: 'p1',
        name: '애월 카페',
        timestamp_sec: 30,
        latitude: 33.1,
        longitude: 126.3,
        address: '제주 애월읍',
        source: 'transcript',
        confidence: 0.9,
        category: 'cafe',
        business_hours: { mon: '09:00-18:00' },
        business_hours_is_estimated: true,
        tags: [{ code: '오션뷰', confidence: 0.8 }],
        mention_note: '뷰가 정말 좋다고 언급함',
      },
    ]);

    const result = await analyzeVideo(YOUTUBE_URL);

    expect(callAiWorker).toHaveBeenNthCalledWith(1, '/extract-transcript', { youtubeUrl: YOUTUBE_URL }, 30000);
    // The first extraction pass gets a minute: gpt-4.1-mini needs 23-28s on a
    // 25-minute vlog, which a 30s budget turned into a failed analysis.
    expect(callAiWorker).toHaveBeenNthCalledWith(2, '/extract-places', expect.any(Object), 60000);
    expect(result.isCached).toBe(false);
    expect(result.videoId).toBe('new-id');
    expect(client.query).toHaveBeenCalledWith('COMMIT');
    expect(redis.set).toHaveBeenCalled();
    expect(result.places[0]).toMatchObject({
      category: 'cafe',
      businessHours: { mon: '09:00-18:00' },
      businessHoursIsEstimated: true,
      tags: [{ code: '오션뷰', confidence: 0.8 }],
      mentionNote: '뷰가 정말 좋다고 언급함',
    });
  });

  it('rolls back the transaction and propagates the error when saving places fails', async () => {
    videoRepository.findByUrl.mockResolvedValue(null);
    callAiWorker.mockResolvedValueOnce({ title: 't', segments: [] }).mockResolvedValueOnce({ places: [] });
    const client = mockDbClient();
    videoRepository.createVideo.mockResolvedValue({ video_id: 'new-id' });
    videoRepository.createPlaces.mockRejectedValue(new Error('insert failed'));

    await expect(analyzeVideo(YOUTUBE_URL)).rejects.toThrow('insert failed');

    expect(client.query).toHaveBeenCalledWith('ROLLBACK');
    expect(client.release).toHaveBeenCalled();
    expect(redis.set).not.toHaveBeenCalled();
  });
});

describe('generateAndStorePlaceEmbeddings', () => {
  it('embeds and stores each place that has coordinates', async () => {
    callAiWorker.mockResolvedValue({ embedding: [0.1, 0.2], model: 'text-embedding-3-small', dimensions: 2 });

    await generateAndStorePlaceEmbeddings([
      { place_id: 'p1', name: 'Place 1', category: 'cafe', address: 'addr', latitude: 37.5, longitude: 127.0 },
    ]);

    expect(callAiWorker).toHaveBeenCalledWith('/embeddings/generate', { text: 'Place 1 | cafe | addr' }, 15000);
    expect(placeEmbeddingRepository.upsert).toHaveBeenCalledWith(
      'p1',
      expect.objectContaining({ embedding: [0.1, 0.2], model: 'text-embedding-3-small', dimensions: 2 })
    );
  });

  it('skips places without coordinates', async () => {
    await generateAndStorePlaceEmbeddings([{ place_id: 'p1', name: 'No coords', latitude: null, longitude: null }]);

    expect(callAiWorker).not.toHaveBeenCalled();
    expect(placeEmbeddingRepository.upsert).not.toHaveBeenCalled();
  });

  it('does not throw when embedding generation fails for a place', async () => {
    callAiWorker.mockRejectedValue(new Error('AI worker down'));

    await expect(
      generateAndStorePlaceEmbeddings([{ place_id: 'p1', name: 'Place 1', latitude: 37.5, longitude: 127.0 }])
    ).resolves.toBeUndefined();

    expect(placeEmbeddingRepository.upsert).not.toHaveBeenCalled();
  });
});

describe('searchByHashtag', () => {
  it('forwards the hashtag to the AI worker and returns its video list', async () => {
    callAiWorker.mockResolvedValue({ videos: [{ videoId: 'v1', youtubeUrl: 'https://youtu.be/v1', title: 't' }] });

    const result = await searchByHashtag('부산여행');

    expect(callAiWorker).toHaveBeenCalledWith('/search-hashtag', { hashtag: '부산여행' }, 10000);
    expect(result).toEqual({ videos: [{ videoId: 'v1', youtubeUrl: 'https://youtu.be/v1', title: 't' }] });
  });

  it('propagates the AppError raised by callAiWorker when the AI worker fails', async () => {
    const AppError = require('../../src/utils/AppError');
    callAiWorker.mockRejectedValue(new AppError(503, 'AI_PROVIDER_ERROR', 'AI Worker request failed'));

    await expect(searchByHashtag('부산여행')).rejects.toMatchObject({ statusCode: 503, code: 'AI_PROVIDER_ERROR' });
  });
});

describe('getRecommendations', () => {
  it('composes regions + themes + duration into a single query and forwards it to the AI worker', async () => {
    callAiWorker.mockResolvedValue({ videos: [{ videoId: 'v1', youtubeUrl: 'https://youtu.be/v1', title: 't' }] });

    const result = await getRecommendations(['제주', '부산'], ['자연', '먹방'], '1박 2일');

    expect(callAiWorker).toHaveBeenCalledWith(
      '/search-videos',
      { query: '제주 부산 자연 먹방 1박 2일 브이로그' },
      10000
    );
    expect(result).toEqual({ videos: [{ videoId: 'v1', youtubeUrl: 'https://youtu.be/v1', title: 't' }] });
  });

  it('propagates the AppError raised by callAiWorker when the AI worker fails', async () => {
    const AppError = require('../../src/utils/AppError');
    callAiWorker.mockRejectedValue(new AppError(503, 'AI_PROVIDER_ERROR', 'AI Worker request failed'));

    await expect(getRecommendations(['제주'], ['자연'], '당일치기')).rejects.toMatchObject({
      statusCode: 503,
      code: 'AI_PROVIDER_ERROR',
    });
  });
});

describe('background screen-text enrichment', () => {
  function mockFreshAnalysis(placeCount) {
    const places = Array.from({ length: placeCount }, (_, i) => ({ name: `장소${i}` }));
    videoRepository.findByUrl.mockResolvedValue(null);
    callAiWorker.mockImplementation((path) => {
      if (path === '/extract-transcript') {
        return Promise.resolve({ title: 't', description: 'd', hashtags: [], segments: [{ text: 'hi' }] });
      }
      if (path === '/extract-places') return Promise.resolve({ places });
      return Promise.resolve({});
    });
    videoRepository.createVideo.mockResolvedValue({
      video_id: 'v1',
      youtube_url: YOUTUBE_URL,
      title: 't',
    });
    videoRepository.createPlaces.mockResolvedValue(
      places.map((p, i) => ({ place_id: `p${i}`, name: p.name, confidence: 0.8 }))
    );
    mockDbClient();
    return places;
  }

  it('reports enrichmentPending and starts the job when the text pass found few places', async () => {
    mockFreshAnalysis(2);

    const result = await analyzeVideo(YOUTUBE_URL);

    expect(result.enrichmentPending).toBe(true);
    expect(videoRepository.setEnrichmentStatus).toHaveBeenCalledWith('v1', 'pending');
    expect(callAiWorker).toHaveBeenCalledWith(
      '/extract-places',
      expect.objectContaining({ forceScreenText: true }),
      expect.any(Number)
    );
  });

  it('enriches even when the text pass already found plenty of places', async () => {
    // A transcript can yield 10 places while more only appear as on-screen
    // overlays -- users reported missing places on exactly those videos.
    mockFreshAnalysis(12);

    const result = await analyzeVideo(YOUTUBE_URL);

    expect(result.enrichmentPending).toBe(true);
    expect(callAiWorker).toHaveBeenCalledWith(
      '/extract-places',
      expect.objectContaining({ forceScreenText: true }),
      expect.any(Number)
    );
  });

  it('catches up an older, never-enriched video when it is opened again', async () => {
    videoRepository.findByUrl.mockResolvedValue({
      video_id: 'old',
      youtube_url: YOUTUBE_URL,
      title: 'Older video',
      is_analyzed: true,
      enrichment_status: null,
    });
    videoRepository.findPlacesByVideoId.mockResolvedValue([{ place_id: 'p1', name: '장소', confidence: 0.8 }]);
    callAiWorker.mockImplementation((path) => {
      if (path === '/extract-transcript') {
        return Promise.resolve({ title: 't', description: 'd', hashtags: [], segments: [] });
      }
      return new Promise(() => {}); // the enrichment is still running
    });

    const result = await analyzeVideo(YOUTUBE_URL);
    await new Promise((resolve) => setImmediate(resolve));

    expect(result.isCached).toBe(true);
    expect(result.enrichmentPending).toBe(true);
    expect(videoRepository.setEnrichmentStatus).toHaveBeenCalledWith('old', 'pending');
    expect(callAiWorker).toHaveBeenCalledWith('/extract-transcript', expect.anything(), expect.any(Number));
    // Caching now would pin enrichmentPending=true after the job finishes.
    expect(redis.set).not.toHaveBeenCalled();
  });

  it('does not re-enrich a video whose enrichment already ran', async () => {
    videoRepository.findByUrl.mockResolvedValue({
      video_id: 'v1',
      youtube_url: YOUTUBE_URL,
      title: 't',
      is_analyzed: true,
      enrichment_status: 'failed',
    });
    videoRepository.findPlacesByVideoId.mockResolvedValue([]);

    await analyzeVideo(YOUTUBE_URL);

    expect(callAiWorker).not.toHaveBeenCalled();
    expect(videoRepository.setEnrichmentStatus).not.toHaveBeenCalled();
  });

  it('never makes the user wait on the enrichment call', async () => {
    mockFreshAnalysis(2);
    let resolveEnrichment;
    callAiWorker.mockImplementation((path, payload) => {
      if (path === '/extract-transcript') {
        return Promise.resolve({ title: 't', description: 'd', hashtags: [], segments: [{ text: 'hi' }] });
      }
      if (path === '/extract-places' && payload.forceScreenText) {
        return new Promise((resolve) => {
          resolveEnrichment = resolve;
        });
      }
      if (path === '/extract-places') return Promise.resolve({ places: [{ name: '장소0' }, { name: '장소1' }] });
      return Promise.resolve({});
    });

    // Resolves even though the enrichment promise is still pending.
    const result = await analyzeVideo(YOUTUBE_URL);

    expect(result.places).toHaveLength(2);
    expect(resolveEnrichment).toBeDefined();
  });
});

describe('merging the screen-text enrichment into the saved places', () => {
  function waitForEnrichmentDone() {
    return new Promise((resolve) => {
      videoRepository.setEnrichmentStatus.mockImplementation(async (videoId, status) => {
        if (status === 'done' || status === 'failed') resolve(status);
      });
    });
  }

  // Each test uses its own video id: an earlier test leaves 'v1' enriching
  // forever, and the in-flight guard would skip another job for it.
  let videoCounter = 0;

  function mockAnalysis({ firstPass, enrichment, savedPlaces, autoGenerated = true }) {
    videoCounter += 1;
    const videoId = `merge-${videoCounter}`;
    videoRepository.findByUrl.mockResolvedValue(null);
    callAiWorker.mockImplementation((path, payload) => {
      if (path === '/extract-transcript') {
        return Promise.resolve({
          title: '대구 당일치기 소베',
          description: '',
          hashtags: [],
          segments: [{ text: '소배라는 베이커리', timestampSec: 266 }],
          captionsAutoGenerated: autoGenerated,
        });
      }
      if (path === '/extract-places') return Promise.resolve({ places: payload.forceScreenText ? enrichment : firstPass });
      return Promise.resolve({ embedding: [0.1], model: 'm', dimensions: 1 });
    });
    videoRepository.createVideo.mockResolvedValue({ video_id: videoId, youtube_url: YOUTUBE_URL, title: 't' });
    videoRepository.createPlaces
      .mockResolvedValueOnce(savedPlaces)
      .mockImplementation(async (client, videoId, places) => places.map((p, i) => ({ place_id: `new${i}`, name: p.name })));
    videoRepository.locatePlace.mockImplementation(async (client, placeId, place) => ({
      place_id: placeId,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
    }));
    placeEmbeddingRepository.upsert.mockResolvedValue(undefined);
    mockDbClient();
    return videoId;
  }

  const soBae = { place_id: 'p0', name: '소배', timestamp_sec: 266, category: 'bakery', latitude: null };
  const mondo = { place_id: 'p1', name: '몬도카츠', timestamp_sec: 785, category: 'restaurant', latitude: '35.86' };

  it('locates a misheard place under its corrected name instead of adding a duplicate, and adds only truly new places', async () => {
    const videoId = mockAnalysis({
      firstPass: [{ name: '소배', timestampSec: 266 }, { name: '몬도카츠', timestampSec: 785 }],
      savedPlaces: [soBae, mondo],
      enrichment: [
        { name: '소베', timestampSec: 267, category: 'bakery', latitude: 35.869, longitude: 128.593, address: '대구 중구' },
        { name: '몬도카츠', timestampSec: 785, category: 'restaurant', latitude: 35.863, longitude: 128.607, address: '대구 중구' },
        { name: '데코와 삼덕점', timestampSec: 1217, category: 'shopping', latitude: 35.864, longitude: 128.608, address: '대구 중구' },
      ],
    });
    const done = waitForEnrichmentDone();

    await analyzeVideo(YOUTUBE_URL);
    expect(await done).toBe('done');

    expect(videoRepository.locatePlace).toHaveBeenCalledTimes(1);
    expect(videoRepository.locatePlace).toHaveBeenCalledWith(
      expect.anything(),
      'p0',
      expect.objectContaining({ name: '소베', latitude: 35.869 })
    );
    // Second createPlaces call is the enrichment's: only the new place.
    expect(videoRepository.createPlaces).toHaveBeenLastCalledWith(expect.anything(), videoId, [
      expect.objectContaining({ name: '데코와 삼덕점' }),
    ]);
  });

  it('leaves a place the first pass already located as it is', async () => {
    mockAnalysis({
      firstPass: [{ name: '몬도카츠', timestampSec: 785 }],
      savedPlaces: [mondo],
      enrichment: [{ name: '몬도 카츠', timestampSec: 786, category: 'restaurant', latitude: 35.9, longitude: 128.9, address: 'x' }],
    });
    const done = waitForEnrichmentDone();

    await analyzeVideo(YOUTUBE_URL);
    await done;

    expect(videoRepository.locatePlace).not.toHaveBeenCalled();
    expect(videoRepository.createPlaces).toHaveBeenCalledTimes(1); // just the first pass
  });

  it('tells the AI worker when the captions were auto-generated, on both passes', async () => {
    mockAnalysis({ firstPass: [], savedPlaces: [], enrichment: [] });
    const done = waitForEnrichmentDone();

    await analyzeVideo(YOUTUBE_URL);
    await done;

    const extractCalls = callAiWorker.mock.calls.filter(([path]) => path === '/extract-places');
    expect(extractCalls).toHaveLength(2);
    extractCalls.forEach(([, payload]) => expect(payload.transcriptAutoGenerated).toBe(true));
  });
});

describe('push notifications for the background enrichment (FR-12)', () => {
  function waitForEnrichmentDone() {
    return new Promise((resolve) => {
      videoRepository.setEnrichmentStatus.mockImplementation(async (videoId, status) => {
        if (status === 'done' || status === 'failed') resolve(status);
      });
    });
  }

  let videoCounter = 0;

  function mockFreshAnalysis({ enrichment = [] } = {}) {
    videoCounter += 1;
    const videoId = `push-${videoCounter}`;
    videoRepository.findByUrl.mockResolvedValue(null);
    callAiWorker.mockImplementation((path, payload) => {
      if (path === '/extract-transcript') {
        return Promise.resolve({ title: '아산 브이로그', description: '', hashtags: [], segments: [{ text: 'hi' }] });
      }
      if (path === '/extract-places') {
        return Promise.resolve({ places: payload.forceScreenText ? enrichment : [{ name: '장소0' }] });
      }
      return Promise.resolve({ embedding: [0.1], model: 'm', dimensions: 1 });
    });
    videoRepository.createVideo.mockResolvedValue({ video_id: videoId, youtube_url: YOUTUBE_URL, title: '아산 브이로그' });
    videoRepository.createPlaces
      .mockResolvedValueOnce([{ place_id: 'p0', name: '장소0', confidence: 0.8 }])
      .mockImplementation(async (client, id, places) => places.map((pl, i) => ({ place_id: `new${i}`, name: pl.name })));
    placeEmbeddingRepository.upsert.mockResolvedValue(undefined);
    mockDbClient();
    return videoId;
  }

  it('remembers a logged-in caller as a watcher while the enrichment is still running', async () => {
    const videoId = mockFreshAnalysis();

    await analyzeVideo(YOUTUBE_URL, 'user-1');

    expect(videoWatcherRepository.add).toHaveBeenCalledWith('user-1', videoId);
  });

  it('does not remember a guest -- analysis needs no login, and there is nobody to notify', async () => {
    mockFreshAnalysis();

    await analyzeVideo(YOUTUBE_URL);

    expect(videoWatcherRepository.add).not.toHaveBeenCalled();
  });

  it('does not remember anyone for a video whose enrichment already finished', async () => {
    videoRepository.findByUrl.mockResolvedValue({
      video_id: 'done-1',
      youtube_url: YOUTUBE_URL,
      title: 't',
      is_analyzed: true,
      enrichment_status: 'done',
    });
    videoRepository.findPlacesByVideoId.mockResolvedValue([]);

    await analyzeVideo(YOUTUBE_URL, 'user-1');

    expect(videoWatcherRepository.add).not.toHaveBeenCalled();
  });

  it('tells every watcher how many places the enrichment added, then forgets them', async () => {
    const videoId = mockFreshAnalysis({ enrichment: [{ name: '새 장소', timestampSec: 10, category: 'cafe' }] });
    videoWatcherRepository.findUserIdsByVideo.mockResolvedValue(['user-1', 'user-2']);
    const done = waitForEnrichmentDone();

    await analyzeVideo(YOUTUBE_URL, 'user-1');
    await done;
    await new Promise((resolve) => setImmediate(resolve));

    expect(pushService.sendToUser).toHaveBeenCalledTimes(2);
    expect(pushService.sendToUser).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({ kind: 'analysisComplete', body: expect.stringContaining('1곳') })
    );
    expect(videoWatcherRepository.removeByVideo).toHaveBeenCalledWith(videoId);
  });

  it('still marks the enrichment done when notifying fails', async () => {
    mockFreshAnalysis();
    videoWatcherRepository.findUserIdsByVideo.mockRejectedValue(new Error('db down'));
    const done = waitForEnrichmentDone();

    await analyzeVideo(YOUTUBE_URL, 'user-1');

    await expect(done).resolves.toBe('done');
  });
});
