jest.mock('../../src/repositories/recommendation.repository');
jest.mock('../../src/repositories/taste-preference.repository');
jest.mock('../../src/services/aiWorkerClient');

const recommendationRepository = require('../../src/repositories/recommendation.repository');
const tastePreferenceRepository = require('../../src/repositories/taste-preference.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { getNearbyRecommendations } = require('../../src/services/recommendation.service');

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

    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 5000, 100);
  });

  it('applies default radius/limit when not provided', async () => {
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 2000, 100);
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
    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userEmbedding: null }),
      10000
    );
  });

  it('fetches and forwards the user preference embedding when the user has one', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [0.9, 0.1] });
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

  it('leaves userTagCodes empty for a guest request', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userTagCodes: [] }),
      10000
    );
  });

  it('fetches and forwards the user preference tag codes when the user has preferences', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [0.9, 0.1], source_tags: ['소금빵', '오션뷰'] });
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ userTagCodes: ['소금빵', '오션뷰'] }),
      10000
    );
  });
});
