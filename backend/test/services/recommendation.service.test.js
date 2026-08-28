jest.mock('../../src/repositories/recommendation.repository');
jest.mock('../../src/repositories/taste-preference.repository');
jest.mock('../../src/repositories/behavior.repository');
jest.mock('../../src/services/aiWorkerClient');

const recommendationRepository = require('../../src/repositories/recommendation.repository');
const tastePreferenceRepository = require('../../src/repositories/taste-preference.repository');
const behaviorRepository = require('../../src/repositories/behavior.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { getNearbyRecommendations, getWalkingCourse } = require('../../src/services/recommendation.service');

beforeEach(() => {
  behaviorRepository.findHiddenPlaceIds.mockResolvedValue([]);
});

afterEach(() => jest.clearAllMocks());

describe('getNearbyRecommendations', () => {
  it('returns an empty list without calling the AI worker when there are no nearby places', async () => {
    recommendationRepository.findNearby.mockResolvedValue([]);

    const result = await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(result).toEqual({ recommendations: [] });
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('maps DB rows to camelCase candidates and forwards them to the AI worker', async () => {
    recommendationRepository.findNearby.mockResolvedValue([
      {
        place_id: 'p1',
        name: 'Place 1',
        latitude: '37.5005',
        longitude: '127.0',
        category: 'cafe',
        business_hours: { mon: { open: '09:00', close: '21:00' } },
      },
    ]);
    callAiWorker.mockResolvedValue({ recommendations: [{ placeId: 'p1' }] });

    const result = await getNearbyRecommendations({
      latitude: 37.5,
      longitude: 127.0,
      localTime: '2026-08-10T12:00:00',
    });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({
        latitude: 37.5,
        longitude: 127.0,
        candidates: [
          {
            placeId: 'p1',
            name: 'Place 1',
            latitude: 37.5005,
            longitude: 127.0,
            category: 'cafe',
            businessHours: { mon: { open: '09:00', close: '21:00' } },
            tags: [],
          },
        ],
      }),
      10000
    );
    expect(result.recommendations).toHaveLength(1);
  });

  it('caps radiusMeters and limit at their maximums before querying', async () => {
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getNearbyRecommendations({
      latitude: 37.5,
      longitude: 127.0,
      localTime: '2026-08-10T12:00:00',
      radiusMeters: 999999,
      limit: 999,
    });

    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 5000, 100, []);
  });

  it('applies default radius/limit when not provided', async () => {
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 2000, 100, []);
  });

  it('passes candidate embeddings through to the AI worker', async () => {
    recommendationRepository.findNearby.mockResolvedValue([
      { place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0', embedding: [0.1, 0.2] },
    ]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ candidates: [expect.objectContaining({ embedding: [0.1, 0.2] })] }),
      10000
    );
  });

  it('leaves userEmbedding null for a guest request (no userId)', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(tastePreferenceRepository.find).not.toHaveBeenCalled();
    expect(behaviorRepository.findHiddenPlaceIds).not.toHaveBeenCalled();
    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userEmbedding: null }),
      10000
    );
  });

  it('fetches and forwards the user preference embedding when the user has one', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [0.9, 0.1], source_tags: [], tag_scores: {} });
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(tastePreferenceRepository.find).toHaveBeenCalledWith('u1');
    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userEmbedding: [0.9, 0.1] }),
      10000
    );
  });

  it('leaves userEmbedding null when the logged-in user has not set preferences yet', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    tastePreferenceRepository.find.mockResolvedValue(null);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userEmbedding: null }),
      10000
    );
  });

  it('passes candidate tags through to the AI worker', async () => {
    recommendationRepository.findNearby.mockResolvedValue([
      { place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0', tags: [{ code: '소금빵', confidence: 0.9 }] },
    ]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({
        candidates: [expect.objectContaining({ tags: [{ code: '소금빵', confidence: 0.9 }] })],
      }),
      10000
    );
  });

  it('leaves userTagScores empty for a guest request', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userTagScores: {} }),
      10000
    );
  });

  it('forwards the learned tag_scores when the user has behavior-nudged preferences', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    tastePreferenceRepository.find.mockResolvedValue({
      user_id: 'u1',
      embedding: [0.9, 0.1],
      source_tags: ['소금빵', '오션뷰'],
      tag_scores: { 소금빵: 1.6, 오션뷰: 0.4 },
    });
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userTagScores: { 소금빵: 1.6, 오션뷰: 0.4 } }),
      10000
    );
  });

  it('falls back to a flat 1.0 per surveyed tag when tag_scores has not been learned yet', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    tastePreferenceRepository.find.mockResolvedValue({
      user_id: 'u1',
      embedding: [0.9, 0.1],
      source_tags: ['소금빵', '오션뷰'],
      tag_scores: null,
    });
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userTagScores: { 소금빵: 1.0, 오션뷰: 1.0 } }),
      10000
    );
  });

  it('excludes places the user hid or marked not-interested from the candidate query', async () => {
    behaviorRepository.findHiddenPlaceIds.mockResolvedValue(['p2', 'p3']);
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(behaviorRepository.findHiddenPlaceIds).toHaveBeenCalledWith('u1');
    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 2000, 100, ['p2', 'p3']);
  });
});

describe('getWalkingCourse', () => {
  it('geocodes the region, queries bookmarked-only candidates around its center, and forwards them', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.4996, longitude: 126.5312, address: '제주특별자치도' });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockResolvedValue([
      { place_id: 'p1', name: '북마크장소', latitude: '33.5', longitude: '126.53', category: 'cafe' },
    ]);

    await getWalkingCourse({ region: '제주', localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith('/geocode', { query: '제주' }, 10000);
    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(33.4996, 126.5312, 3000, 60, [], true);
    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({
        regionName: '제주',
        centerLatitude: 33.4996,
        centerLongitude: 126.5312,
        localTime: '2026-08-10T12:00:00',
        radiusMeters: 3000,
        bookmarkCandidates: [
          expect.objectContaining({ placeId: 'p1', name: '북마크장소', latitude: 33.5, longitude: 126.53, category: 'cafe' }),
        ],
      }),
      15000
    );
  });

  it('lets a GEOCODING_FAILED error from the AI worker propagate unchanged', async () => {
    const AppError = require('../../src/utils/AppError');
    callAiWorker.mockRejectedValue(new AppError(503, 'GEOCODING_FAILED', "Could not geocode '존재하지않는지역'"));

    await expect(getWalkingCourse({ region: '존재하지않는지역', localTime: '2026-08-10T12:00:00' })).rejects.toMatchObject({
      statusCode: 503,
      code: 'GEOCODING_FAILED',
    });
    expect(recommendationRepository.findNearby).not.toHaveBeenCalled();
  });

  it('forwards the learned taste preference for a logged-in user, and null for a guest', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockResolvedValue([]);
    tastePreferenceRepository.find.mockResolvedValue({
      user_id: 'u1',
      embedding: [0.1, 0.2],
      source_tags: ['오션뷰'],
      tag_scores: { 오션뷰: 1.5 },
    });

    await getWalkingCourse({ userId: 'u1', region: '제주', localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ userEmbedding: [0.1, 0.2], userTagScores: { 오션뷰: 1.5 } }),
      15000
    );

    jest.clearAllMocks();
    behaviorRepository.findHiddenPlaceIds.mockResolvedValue([]);
    recommendationRepository.findNearby.mockResolvedValue([]);
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });

    await getWalkingCourse({ region: '제주', localTime: '2026-08-10T12:00:00' });

    expect(tastePreferenceRepository.find).not.toHaveBeenCalled();
    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ userEmbedding: null, userTagScores: {} }),
      15000
    );
  });
});
