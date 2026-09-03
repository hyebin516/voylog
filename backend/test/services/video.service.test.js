jest.mock('../../src/config/db');
jest.mock('../../src/config/redis');
jest.mock('../../src/repositories/video.repository');
jest.mock('../../src/repositories/place-embedding.repository');
jest.mock('../../src/services/aiWorkerClient');

const pool = require('../../src/config/db');
const redis = require('../../src/config/redis');
const videoRepository = require('../../src/repositories/video.repository');
const placeEmbeddingRepository = require('../../src/repositories/place-embedding.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
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
    videoRepository.findByUrl.mockResolvedValue({ video_id: 'v1', title: 'Existing', is_analyzed: true });
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
    videoRepository.createVideo.mockResolvedValue({ video_id: 'new-id', title: 'New video' });
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

    const result = await getRecommendations(['제주', '부산'], ['자연', '먹방'], '1박2일');

    expect(callAiWorker).toHaveBeenCalledWith(
      '/search-videos',
      { query: '제주 부산 자연 먹방 1박2일 브이로그' },
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
