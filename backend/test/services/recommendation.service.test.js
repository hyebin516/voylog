jest.mock('../../src/repositories/recommendation.repository');
jest.mock('../../src/services/aiWorkerClient');

const recommendationRepository = require('../../src/repositories/recommendation.repository');
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
});
