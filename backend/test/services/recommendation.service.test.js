jest.mock('../../src/repositories/recommendation.repository');
jest.mock('../../src/repositories/taste-preference.repository');
jest.mock('../../src/repositories/behavior.repository');
jest.mock('../../src/repositories/bookmark.repository');
jest.mock('../../src/services/aiWorkerClient');
jest.mock('../../src/services/place-embedding.service');

const recommendationRepository = require('../../src/repositories/recommendation.repository');
const tastePreferenceRepository = require('../../src/repositories/taste-preference.repository');
const behaviorRepository = require('../../src/repositories/behavior.repository');
const bookmarkRepository = require('../../src/repositories/bookmark.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { ensurePlaceEmbeddings } = require('../../src/services/place-embedding.service');
const {
  getNearbyRecommendations,
  getWalkingCourse,
  getSimilarTasteRecommendations,
} = require('../../src/services/recommendation.service');

beforeEach(() => {
  behaviorRepository.findHiddenPlaceIds.mockResolvedValue([]);
  ensurePlaceEmbeddings.mockImplementation(async (places) => places);
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
        address: '서울 중구 세종대로 110',
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
            address: '서울 중구 세종대로 110',
            category: 'cafe',
            businessHours: { mon: { open: '09:00', close: '21:00' } },
            businessHoursIsEstimated: false,
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

    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 5000, 100, [], false, null);
  });

  it('applies default radius/limit when not provided', async () => {
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 2000, 100, [], false, null);
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

  it('embeds candidates missing an embedding when the user has a taste embedding', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [0.9, 0.1], source_tags: [], tag_scores: {} });
    ensurePlaceEmbeddings.mockImplementation(async (places) => places.map((p) => ({ ...p, embedding: [0.3, 0.7] })));
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/nearby-score',
      expect.objectContaining({ candidates: [expect.objectContaining({ placeId: 'p1', embedding: [0.3, 0.7] })] }),
      10000
    );
  });

  it('does not embed candidates for a guest, who has nothing to compare them with', async () => {
    recommendationRepository.findNearby.mockResolvedValue([{ place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0' }]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getNearbyRecommendations({ latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(ensurePlaceEmbeddings).not.toHaveBeenCalled();
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

  it('narrows candidates to the requested category group before scoring', async () => {
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getNearbyRecommendations({
      latitude: 37.5,
      longitude: 127.0,
      localTime: '2026-08-10T20:30:00',
      categoryGroup: 'cafe',
    });

    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 2000, 100, [], false, ['cafe', 'bakery']);
  });

  it('excludes places the user hid or marked not-interested from the candidate query', async () => {
    behaviorRepository.findHiddenPlaceIds.mockResolvedValue(['p2', 'p3']);
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getNearbyRecommendations({ userId: 'u1', latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00' });

    expect(behaviorRepository.findHiddenPlaceIds).toHaveBeenCalledWith('u1');
    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(37.5, 127.0, 2000, 100, ['p2', 'p3'], false, null);
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
    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(33.4996, 126.5312, 3000, 150, [], false);
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

  it('also forwards nearby stored places, minus the ones already sent as bookmarks', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockImplementation((lat, lng, radius, limit, exclude, bookmarkedOnly) =>
      Promise.resolve(
        bookmarkedOnly
          ? [{ place_id: 'p1', name: '북마크장소', latitude: '33.5', longitude: '126.5' }]
          : [
              { place_id: 'p1', name: '북마크장소', latitude: '33.5', longitude: '126.5' },
              { place_id: 'p2', name: '경복궁', latitude: '33.5', longitude: '126.5', category: 'attraction' },
            ]
      )
    );

    await getWalkingCourse({ region: '제주', localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ placeCandidates: [expect.objectContaining({ placeId: 'p2', name: '경복궁' })] }),
      15000
    );
  });

  it('forwards a user-chosen start point as the course start/end', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getWalkingCourse({
      userId: 'u1',
      region: '제주',
      localTime: '2026-08-10T12:00:00',
      startLatitude: 33.51,
      startLongitude: 126.52,
      startName: '제주공항 앞',
    });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({
        startPoint: {
          pointId: 'start-point',
          name: '제주공항 앞',
          latitude: 33.51,
          longitude: 126.52,
        },
      }),
      15000
    );
  });

  it('searches for places around the start point instead of the region center', async () => {
    callAiWorker.mockResolvedValue({ course: null, recommendations: [] });
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getWalkingCourse({
      region: '제주',
      localTime: '2026-08-10T12:00:00',
      startLatitude: 33.51,
      startLongitude: 126.52,
    });

    // Geocoding the region would recenter the search and make the start
    // point change nothing but the route's endpoints.
    expect(callAiWorker).not.toHaveBeenCalledWith('/geocode', expect.anything(), expect.anything());
    expect(recommendationRepository.findNearby).toHaveBeenCalledWith(
      33.51,
      126.52,
      expect.any(Number),
      expect.any(Number),
      expect.any(Array),
      true
    );
    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ centerLatitude: 33.51, centerLongitude: 126.52 }),
      15000
    );
  });

  it('forwards the previous course places to avoid when regenerating', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getWalkingCourse({ region: '제주', localTime: '2026-08-10T12:00:00', avoidPlaceIds: ['p1', 'kakao:9'] });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ avoidPlaceIds: ['p1', 'kakao:9'] }),
      15000
    );
  });

  it('names an unnamed start point rather than sending it blank', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getWalkingCourse({
      region: '제주',
      localTime: '2026-08-10T12:00:00',
      startLatitude: 33.51,
      startLongitude: 126.52,
    });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ startPoint: expect.objectContaining({ name: '출발 지점' }) }),
      15000
    );
  });

  it('sends a null startPoint when the user did not choose one', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getWalkingCourse({ region: '제주', localTime: '2026-08-10T12:00:00' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ startPoint: null }),
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

  it('forwards mood and walkDuration to the AI worker when provided', async () => {
    callAiWorker.mockImplementation((path) => {
      if (path === '/geocode') return Promise.resolve({ latitude: 33.5, longitude: 126.5 });
      return Promise.resolve({ course: null, recommendations: [] });
    });
    recommendationRepository.findNearby.mockResolvedValue([]);

    await getWalkingCourse({ region: '제주', localTime: '2026-08-10T12:00:00', mood: '힙한', walkDuration: '2~3시간' });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/walking-course',
      expect.objectContaining({ mood: '힙한', walkDuration: '2~3시간' }),
      15000
    );
  });
});

describe('getSimilarTasteRecommendations', () => {
  it('returns an empty list without calling the AI worker when the requester has no preference embedding', async () => {
    tastePreferenceRepository.find.mockResolvedValue(null);

    const result = await getSimilarTasteRecommendations({ userId: 'u1' });

    expect(result).toEqual({ recommendations: [], hasPreference: false });
    expect(callAiWorker).not.toHaveBeenCalled();
    expect(tastePreferenceRepository.findAllExcept).not.toHaveBeenCalled();
  });

  it('returns an empty list without calling the AI worker when no other user has a preference embedding yet', async () => {
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [1, 0] });
    tastePreferenceRepository.findAllExcept.mockResolvedValue([]);

    const result = await getSimilarTasteRecommendations({ userId: 'u1' });

    expect(result).toEqual({ recommendations: [], hasPreference: true });
    expect(callAiWorker).not.toHaveBeenCalled();
    expect(bookmarkRepository.findByUsers).not.toHaveBeenCalled();
  });

  it('excludes the requester\'s own bookmarks and hidden places, and groups other users\' bookmarks by user', async () => {
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [1, 0] });
    tastePreferenceRepository.findAllExcept.mockResolvedValue([
      { user_id: 'u2', embedding: [0.9, 0.1] },
      { user_id: 'u3', embedding: [0.8, 0.2] },
    ]);
    bookmarkRepository.findAllByUser.mockResolvedValue([{ place_id: 'my-place' }]);
    behaviorRepository.findHiddenPlaceIds.mockResolvedValue(['hidden-place']);
    bookmarkRepository.findByUsers.mockResolvedValue([
      { user_id: 'u2', place_id: 'p1', name: 'Place 1', latitude: '37.5', longitude: '127.0', category: 'cafe' },
      { user_id: 'u3', place_id: 'p2', name: 'Place 2', latitude: '37.6', longitude: '127.1', category: null },
    ]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getSimilarTasteRecommendations({ userId: 'u1' });

    expect(bookmarkRepository.findByUsers).toHaveBeenCalledWith(['u2', 'u3'], ['my-place', 'hidden-place']);
    expect(callAiWorker).toHaveBeenCalledWith(
      '/recommendations/similar-taste-score',
      {
        userEmbedding: [1, 0],
        otherUsers: [
          {
            userId: 'u2',
            embedding: [0.9, 0.1],
            bookmarkedPlaces: [{ placeId: 'p1', name: 'Place 1', latitude: 37.5, longitude: 127.0, category: 'cafe' }],
          },
          {
            userId: 'u3',
            embedding: [0.8, 0.2],
            bookmarkedPlaces: [{ placeId: 'p2', name: 'Place 2', latitude: 37.6, longitude: 127.1, category: null }],
          },
        ],
        limit: 20,
      },
      10000
    );
  });

  it('caps limit at its maximum', async () => {
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [1, 0] });
    tastePreferenceRepository.findAllExcept.mockResolvedValue([{ user_id: 'u2', embedding: [0.9, 0.1] }]);
    bookmarkRepository.findAllByUser.mockResolvedValue([]);
    bookmarkRepository.findByUsers.mockResolvedValue([]);
    callAiWorker.mockResolvedValue({ recommendations: [] });

    await getSimilarTasteRecommendations({ userId: 'u1', limit: 999 });

    expect(callAiWorker).toHaveBeenCalledWith('/recommendations/similar-taste-score', expect.objectContaining({ limit: 50 }), 10000);
  });

  it('returns hasPreference: true alongside the AI worker result on success', async () => {
    tastePreferenceRepository.find.mockResolvedValue({ user_id: 'u1', embedding: [1, 0] });
    tastePreferenceRepository.findAllExcept.mockResolvedValue([{ user_id: 'u2', embedding: [0.9, 0.1] }]);
    bookmarkRepository.findAllByUser.mockResolvedValue([]);
    bookmarkRepository.findByUsers.mockResolvedValue([]);
    callAiWorker.mockResolvedValue({ recommendations: [{ placeId: 'p1' }] });

    const result = await getSimilarTasteRecommendations({ userId: 'u1' });

    expect(result).toEqual({ recommendations: [{ placeId: 'p1' }], hasPreference: true });
  });
});
