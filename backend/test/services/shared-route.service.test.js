jest.mock('../../src/repositories/shared-route.repository');
jest.mock('../../src/repositories/route-like.repository');
jest.mock('../../src/repositories/taste-preference.repository');
jest.mock('../../src/services/behavior.service');
jest.mock('../../src/services/aiWorkerClient');

const sharedRouteRepository = require('../../src/repositories/shared-route.repository');
const routeLikeRepository = require('../../src/repositories/route-like.repository');
const tastePreferenceRepository = require('../../src/repositories/taste-preference.repository');
const behaviorService = require('../../src/services/behavior.service');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const sharedRouteService = require('../../src/services/shared-route.service');

const VIEWER_ID = 'viewer-1';
const AUTHOR_ID = 'author-1';
const ROUTE_ID = 'route-1';

afterEach(() => jest.clearAllMocks());

describe('getSharedRouteFeed', () => {
  it('returns null matchPercent for every row when there is no viewer (guest)', async () => {
    sharedRouteRepository.findFeed.mockResolvedValue([{ shared_route_id: ROUTE_ID, user_id: AUTHOR_ID }]);

    const result = await sharedRouteService.getSharedRouteFeed({ viewerUserId: null, limit: 20 });

    expect(result[0].match_percent).toBeNull();
    expect(tastePreferenceRepository.find).not.toHaveBeenCalled();
  });

  it('returns null matchPercent when the viewer has no taste preference embedding', async () => {
    sharedRouteRepository.findFeed.mockResolvedValue([{ shared_route_id: ROUTE_ID, user_id: AUTHOR_ID }]);
    tastePreferenceRepository.find.mockResolvedValue(null);

    const result = await sharedRouteService.getSharedRouteFeed({ viewerUserId: VIEWER_ID, limit: 20 });

    expect(result[0].match_percent).toBeNull();
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('computes matchPercent from the AI worker similarity score, clamped and rounded to a percentage', async () => {
    sharedRouteRepository.findFeed.mockResolvedValue([{ shared_route_id: ROUTE_ID, user_id: AUTHOR_ID }]);
    tastePreferenceRepository.find.mockResolvedValue({ embedding: [1, 0] });
    tastePreferenceRepository.findByUserIds.mockResolvedValue([{ user_id: AUTHOR_ID, embedding: [1, 0] }]);
    callAiWorker.mockResolvedValue({ similarities: [{ key: AUTHOR_ID, score: 0.913 }] });

    const result = await sharedRouteService.getSharedRouteFeed({ viewerUserId: VIEWER_ID, limit: 20 });

    expect(callAiWorker).toHaveBeenCalledWith(
      '/embeddings/similarity',
      { embeddingA: [1, 0], embeddingsB: [{ key: AUTHOR_ID, embedding: [1, 0] }] },
      10000
    );
    expect(result[0].match_percent).toBe(91);
  });

  it('clamps a negative similarity score to 0% instead of a negative percentage', async () => {
    sharedRouteRepository.findFeed.mockResolvedValue([{ shared_route_id: ROUTE_ID, user_id: AUTHOR_ID }]);
    tastePreferenceRepository.find.mockResolvedValue({ embedding: [1, 0] });
    tastePreferenceRepository.findByUserIds.mockResolvedValue([{ user_id: AUTHOR_ID, embedding: [-1, 0] }]);
    callAiWorker.mockResolvedValue({ similarities: [{ key: AUTHOR_ID, score: -0.5 }] });

    const result = await sharedRouteService.getSharedRouteFeed({ viewerUserId: VIEWER_ID, limit: 20 });

    expect(result[0].match_percent).toBe(0);
  });

  it('does not call the AI worker at all when no author in the feed has a preference embedding', async () => {
    sharedRouteRepository.findFeed.mockResolvedValue([{ shared_route_id: ROUTE_ID, user_id: AUTHOR_ID }]);
    tastePreferenceRepository.find.mockResolvedValue({ embedding: [1, 0] });
    tastePreferenceRepository.findByUserIds.mockResolvedValue([]);

    const result = await sharedRouteService.getSharedRouteFeed({ viewerUserId: VIEWER_ID, limit: 20 });

    expect(callAiWorker).not.toHaveBeenCalled();
    expect(result[0].match_percent).toBeNull();
  });

  it('excludes the viewer\'s own row from the similarity batch (no self-comparison) and leaves it without a matchPercent', async () => {
    sharedRouteRepository.findFeed.mockResolvedValue([
      { shared_route_id: 'my-route', user_id: VIEWER_ID },
      { shared_route_id: ROUTE_ID, user_id: AUTHOR_ID },
    ]);
    tastePreferenceRepository.find.mockResolvedValue({ embedding: [1, 0] });
    tastePreferenceRepository.findByUserIds.mockResolvedValue([{ user_id: AUTHOR_ID, embedding: [1, 0] }]);
    callAiWorker.mockResolvedValue({ similarities: [{ key: AUTHOR_ID, score: 1 }] });

    const result = await sharedRouteService.getSharedRouteFeed({ viewerUserId: VIEWER_ID, limit: 20 });

    expect(tastePreferenceRepository.findByUserIds).toHaveBeenCalledWith([AUTHOR_ID]);
    const myRow = result.find((r) => r.shared_route_id === 'my-route');
    expect(myRow.match_percent).toBeNull();
  });
});

describe('updateTitle', () => {
  it('updates the title of a shared route owned by the requesting user', async () => {
    sharedRouteRepository.findById.mockResolvedValue({ shared_route_id: ROUTE_ID, user_id: VIEWER_ID });
    sharedRouteRepository.updateTitle.mockResolvedValue({ shared_route_id: ROUTE_ID, title: '새 제목' });

    const result = await sharedRouteService.updateTitle(VIEWER_ID, ROUTE_ID, '새 제목');

    expect(sharedRouteRepository.updateTitle).toHaveBeenCalledWith(ROUTE_ID, '새 제목');
    expect(result.title).toBe('새 제목');
  });

  it('refuses to update a shared route owned by another user', async () => {
    sharedRouteRepository.findById.mockResolvedValue({ shared_route_id: ROUTE_ID, user_id: 'someone-else' });

    await expect(sharedRouteService.updateTitle(VIEWER_ID, ROUTE_ID, '새 제목')).rejects.toMatchObject({
      statusCode: 404,
      code: 'SHARED_ROUTE_NOT_FOUND',
    });
    expect(sharedRouteRepository.updateTitle).not.toHaveBeenCalled();
  });
});

describe('unpublish', () => {
  it('soft-deletes a shared route owned by the requesting user', async () => {
    sharedRouteRepository.findById.mockResolvedValue({ shared_route_id: ROUTE_ID, user_id: VIEWER_ID });

    await sharedRouteService.unpublish(VIEWER_ID, ROUTE_ID);

    expect(sharedRouteRepository.softDelete).toHaveBeenCalledWith(ROUTE_ID);
  });

  it('refuses to unpublish a shared route owned by another user', async () => {
    sharedRouteRepository.findById.mockResolvedValue({ shared_route_id: ROUTE_ID, user_id: 'someone-else' });

    await expect(sharedRouteService.unpublish(VIEWER_ID, ROUTE_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'SHARED_ROUTE_NOT_FOUND',
    });
    expect(sharedRouteRepository.softDelete).not.toHaveBeenCalled();
  });
});

describe('like/unlike', () => {
  const PLACE_ID_1 = '11111111-1111-1111-1111-111111111111';
  const PLACE_ID_2 = '22222222-2222-2222-2222-222222222222';
  const ROUTE_DATA = [
    { order: 0, type: 'place', placeId: PLACE_ID_1, name: 'Place 1' },
    { order: 1, type: 'place', placeId: PLACE_ID_2, name: 'Place 2' },
  ];

  it('likes an existing shared route owned by someone else', async () => {
    sharedRouteRepository.findById.mockResolvedValue({ shared_route_id: ROUTE_ID, user_id: AUTHOR_ID, route_data: [] });

    await sharedRouteService.like(VIEWER_ID, ROUTE_ID);

    expect(routeLikeRepository.like).toHaveBeenCalledWith(VIEWER_ID, ROUTE_ID);
  });

  it('throws 404 SHARED_ROUTE_NOT_FOUND when liking a route that does not exist', async () => {
    sharedRouteRepository.findById.mockResolvedValue(null);

    await expect(sharedRouteService.like(VIEWER_ID, ROUTE_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'SHARED_ROUTE_NOT_FOUND',
    });
    expect(routeLikeRepository.like).not.toHaveBeenCalled();
  });

  it('refuses to like your own shared route', async () => {
    sharedRouteRepository.findById.mockResolvedValue({ shared_route_id: ROUTE_ID, user_id: VIEWER_ID, route_data: [] });

    await expect(sharedRouteService.like(VIEWER_ID, ROUTE_ID)).rejects.toMatchObject({
      statusCode: 400,
      code: 'INVALID_REQUEST',
    });
    expect(routeLikeRepository.like).not.toHaveBeenCalled();
  });

  it('feeds each place in the liked route into the liker\'s taste weight via the existing FR-15 behavior pipeline', async () => {
    sharedRouteRepository.findById.mockResolvedValue({
      shared_route_id: ROUTE_ID,
      user_id: AUTHOR_ID,
      route_data: ROUTE_DATA,
    });

    await sharedRouteService.like(VIEWER_ID, ROUTE_ID);

    expect(behaviorService.recordBehavior).toHaveBeenCalledWith(VIEWER_ID, {
      placeId: PLACE_ID_1,
      action: 'like',
      screen: 'shared_route_feed',
    });
    expect(behaviorService.recordBehavior).toHaveBeenCalledWith(VIEWER_ID, {
      placeId: PLACE_ID_2,
      action: 'like',
      screen: 'shared_route_feed',
    });
    expect(behaviorService.recordBehavior).toHaveBeenCalledTimes(2);
  });

  it('filters out non-UUID place ids (Kakao 상권 검색 candidates that were never saved to `places`) instead of querying with them', async () => {
    sharedRouteRepository.findById.mockResolvedValue({
      shared_route_id: ROUTE_ID,
      user_id: AUTHOR_ID,
      route_data: [
        { order: 0, type: 'place', placeId: 'kakao:7913306', name: 'Kakao candidate' },
        { order: 1, type: 'place', placeId: PLACE_ID_1, name: 'Real place' },
      ],
    });

    await sharedRouteService.like(VIEWER_ID, ROUTE_ID);

    expect(behaviorService.recordBehavior).toHaveBeenCalledTimes(1);
    expect(behaviorService.recordBehavior).toHaveBeenCalledWith(VIEWER_ID, {
      placeId: PLACE_ID_1,
      action: 'like',
      screen: 'shared_route_feed',
    });
  });

  it('does not let a taste-weight update failure break the like itself (best-effort)', async () => {
    sharedRouteRepository.findById.mockResolvedValue({
      shared_route_id: ROUTE_ID,
      user_id: AUTHOR_ID,
      route_data: ROUTE_DATA,
    });
    behaviorService.recordBehavior.mockRejectedValue(new Error('AI worker unreachable'));

    await expect(sharedRouteService.like(VIEWER_ID, ROUTE_ID)).resolves.toBeUndefined();
    expect(routeLikeRepository.like).toHaveBeenCalledWith(VIEWER_ID, ROUTE_ID);
  });

  it('unlikes without requiring the route to still exist (idempotent cleanup)', async () => {
    sharedRouteRepository.findById.mockResolvedValue(null);

    await sharedRouteService.unlike(VIEWER_ID, ROUTE_ID);

    expect(routeLikeRepository.unlike).toHaveBeenCalledWith(VIEWER_ID, ROUTE_ID);
    expect(behaviorService.reverseScopedBehavior).not.toHaveBeenCalled();
  });

  it('reverses the taste-weight nudge for each place when unliking a route that still exists', async () => {
    sharedRouteRepository.findById.mockResolvedValue({
      shared_route_id: ROUTE_ID,
      user_id: AUTHOR_ID,
      route_data: ROUTE_DATA,
    });

    await sharedRouteService.unlike(VIEWER_ID, ROUTE_ID);

    expect(behaviorService.reverseScopedBehavior).toHaveBeenCalledWith(
      VIEWER_ID,
      PLACE_ID_1,
      'like',
      'shared_route_feed'
    );
    expect(behaviorService.reverseScopedBehavior).toHaveBeenCalledWith(
      VIEWER_ID,
      PLACE_ID_2,
      'like',
      'shared_route_feed'
    );
    expect(behaviorService.reverseScopedBehavior).toHaveBeenCalledTimes(2);
  });

  it('does not let a taste-weight reversal failure break the unlike itself (best-effort)', async () => {
    sharedRouteRepository.findById.mockResolvedValue({
      shared_route_id: ROUTE_ID,
      user_id: AUTHOR_ID,
      route_data: ROUTE_DATA,
    });
    behaviorService.reverseScopedBehavior.mockRejectedValue(new Error('AI worker unreachable'));

    await expect(sharedRouteService.unlike(VIEWER_ID, ROUTE_ID)).resolves.toBeUndefined();
    expect(routeLikeRepository.unlike).toHaveBeenCalledWith(VIEWER_ID, ROUTE_ID);
  });
});
