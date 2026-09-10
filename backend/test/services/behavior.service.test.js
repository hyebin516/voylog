jest.mock('../../src/repositories/behavior.repository');
jest.mock('../../src/repositories/place.repository');
jest.mock('../../src/repositories/place-embedding.repository');
jest.mock('../../src/repositories/taste-preference.repository');
jest.mock('../../src/services/aiWorkerClient');

const behaviorRepository = require('../../src/repositories/behavior.repository');
const placeRepository = require('../../src/repositories/place.repository');
const placeEmbeddingRepository = require('../../src/repositories/place-embedding.repository');
const tastePreferenceRepository = require('../../src/repositories/taste-preference.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { recordBehavior, reverseScopedBehavior } = require('../../src/services/behavior.service');

const USER_ID = 'user-1';
const PLACE_ID = 'place-1';

beforeEach(() => {
  behaviorRepository.create.mockResolvedValue({ behavior_id: 'b1' });
  behaviorRepository.countPastActions.mockResolvedValue(0);
  behaviorRepository.deleteMostRecent.mockResolvedValue(null);
  behaviorRepository.countAll.mockResolvedValue(0);
  placeRepository.findByIds.mockResolvedValue([{ place_id: PLACE_ID, tags: [] }]);
  placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([]);
  tastePreferenceRepository.find.mockResolvedValue(null);
  tastePreferenceRepository.updateFromBehavior.mockResolvedValue({});
});

afterEach(() => jest.clearAllMocks());

describe('recordBehavior', () => {
  it('logs the behavior row with a bucketed distance and the model version', async () => {
    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark', screen: 'nearby', distanceMeters: 150 });

    expect(behaviorRepository.create).toHaveBeenCalledWith(USER_ID, PLACE_ID, 'bookmark', {
      screen: 'nearby',
      distanceBucket: '0-200m',
      modelVersion: 'hybrid-v1',
    });
  });

  it('leaves distanceBucket null when distanceMeters is not provided', async () => {
    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'view_detail' });

    expect(behaviorRepository.create).toHaveBeenCalledWith(
      USER_ID,
      PLACE_ID,
      'view_detail',
      expect.objectContaining({ distanceBucket: null })
    );
  });

  it('does nothing further when the place no longer exists', async () => {
    placeRepository.findByIds.mockResolvedValue([]);

    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark' });

    expect(callAiWorker).not.toHaveBeenCalled();
    expect(tastePreferenceRepository.updateFromBehavior).not.toHaveBeenCalled();
  });

  it('does not persist a preference update when there is no place embedding and no prior preference', async () => {
    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark' });

    expect(callAiWorker).not.toHaveBeenCalled();
    expect(tastePreferenceRepository.updateFromBehavior).not.toHaveBeenCalled();
  });

  it('still updates tag scores from the prior preference embedding when the place has no embedding of its own (e.g. generation failed)', async () => {
    placeRepository.findByIds.mockResolvedValue([
      { place_id: PLACE_ID, tags: [{ code: '소금빵', confidence: 1.0 }] },
    ]);
    tastePreferenceRepository.find.mockResolvedValue({
      embedding: [1.0, 0.0],
      model: 'text-embedding-3-small',
      dimensions: 2,
      tag_scores: {},
    });

    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark' });

    expect(callAiWorker).not.toHaveBeenCalled();
    expect(tastePreferenceRepository.updateFromBehavior).toHaveBeenCalledWith(USER_ID, {
      embedding: [1.0, 0.0],
      tagScores: { 소금빵: 0.6 },
      model: 'text-embedding-3-small',
      dimensions: 2,
    });
  });

  it('nudges a fresh preference embedding toward the place embedding when the user has none yet', async () => {
    placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([
      { place_id: PLACE_ID, embedding: [1.0, 0.0], model: 'text-embedding-3-small', dimensions: 2 },
    ]);
    callAiWorker.mockResolvedValue({ embedding: [1.0, 0.0] });

    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark' });

    // bookmark weight 4, pastCount 0 -> damping 1, learning rate 0.15 -> 0.6
    expect(callAiWorker).toHaveBeenCalledWith(
      '/embeddings/update-preference',
      { currentEmbedding: null, placeEmbedding: [1.0, 0.0], weight: 0.6 },
      15000
    );
    expect(tastePreferenceRepository.updateFromBehavior).toHaveBeenCalledWith(USER_ID, {
      embedding: [1.0, 0.0],
      tagScores: {},
      model: 'text-embedding-3-small',
      dimensions: 2,
    });
  });

  it('raises the score for tags the place has, weighted by tag confidence', async () => {
    placeRepository.findByIds.mockResolvedValue([
      { place_id: PLACE_ID, tags: [{ code: '소금빵', confidence: 0.8 }] },
    ]);
    tastePreferenceRepository.find.mockResolvedValue({
      embedding: [1.0, 0.0],
      model: 'text-embedding-3-small',
      dimensions: 2,
      tag_scores: { 소금빵: 1.0 },
    });
    placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([
      { place_id: PLACE_ID, embedding: [1.0, 0.0], model: 'text-embedding-3-small', dimensions: 2 },
    ]);
    callAiWorker.mockResolvedValue({ embedding: [1.0, 0.0] });

    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark' });

    // 1.0 + (0.6 effective weight * 0.8 confidence) = 1.48
    expect(tastePreferenceRepository.updateFromBehavior).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({ tagScores: { 소금빵: 1.48 } })
    );
  });

  it('lowers matched tag scores for a negative action like not_interested', async () => {
    placeRepository.findByIds.mockResolvedValue([
      { place_id: PLACE_ID, tags: [{ code: '소금빵', confidence: 1.0 }] },
    ]);
    tastePreferenceRepository.find.mockResolvedValue({
      embedding: [1.0, 0.0],
      model: 'text-embedding-3-small',
      dimensions: 2,
      tag_scores: { 소금빵: 1.0 },
    });
    placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([
      { place_id: PLACE_ID, embedding: [1.0, 0.0], model: 'text-embedding-3-small', dimensions: 2 },
    ]);
    callAiWorker.mockResolvedValue({ embedding: [0.9, 0.1] });

    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'not_interested' });

    // not_interested weight -5, pastCount 0 -> damping 1 -> effective -0.75
    // 1.0 + (-0.75 * 1.0) = 0.25
    expect(tastePreferenceRepository.updateFromBehavior).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({ tagScores: { 소금빵: 0.25 } })
    );
  });

  it('clamps tag scores to the [-2, 2] range', async () => {
    placeRepository.findByIds.mockResolvedValue([
      { place_id: PLACE_ID, tags: [{ code: '소금빵', confidence: 1.0 }] },
    ]);
    tastePreferenceRepository.find.mockResolvedValue({
      embedding: [1.0, 0.0],
      model: 'text-embedding-3-small',
      dimensions: 2,
      tag_scores: { 소금빵: 1.95 },
    });
    placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([
      { place_id: PLACE_ID, embedding: [1.0, 0.0], model: 'text-embedding-3-small', dimensions: 2 },
    ]);
    callAiWorker.mockResolvedValue({ embedding: [1.0, 0.0] });

    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark' });

    expect(tastePreferenceRepository.updateFromBehavior).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({ tagScores: { 소금빵: 2 } })
    );
  });

  it('dampens the effective weight for repeated occurrences of the same action on the same place', async () => {
    behaviorRepository.countPastActions.mockResolvedValue(3);
    placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([
      { place_id: PLACE_ID, embedding: [1.0, 0.0], model: 'text-embedding-3-small', dimensions: 2 },
    ]);
    callAiWorker.mockResolvedValue({ embedding: [1.0, 0.0] });

    await recordBehavior(USER_ID, { placeId: PLACE_ID, action: 'bookmark' });

    // bookmark weight 4, pastCount 3 -> damping 1/sqrt(4) = 0.5, learning rate 0.15 -> 0.3
    expect(callAiWorker).toHaveBeenCalledWith(
      '/embeddings/update-preference',
      { currentEmbedding: null, placeEmbedding: [1.0, 0.0], weight: 0.3 },
      15000
    );
  });
});

describe('reverseScopedBehavior', () => {
  it('does nothing when there is no matching behavior row to undo', async () => {
    behaviorRepository.deleteMostRecent.mockResolvedValue(null);

    await reverseScopedBehavior(USER_ID, PLACE_ID, 'like', 'shared_route_feed');

    expect(behaviorRepository.countPastActions).not.toHaveBeenCalled();
    expect(callAiWorker).not.toHaveBeenCalled();
    expect(tastePreferenceRepository.updateFromBehavior).not.toHaveBeenCalled();
  });

  it('fully resets the preference row when the undone like was the only signal that ever formed it (no survey, no other behavior)', async () => {
    behaviorRepository.deleteMostRecent.mockResolvedValue({ behavior_id: 'b1' });
    behaviorRepository.countAll.mockResolvedValue(0);
    tastePreferenceRepository.find.mockResolvedValue({
      embedding: [1.0, 0.0],
      source_tags: [],
      tag_scores: { 소금빵: 0.75 },
    });

    await reverseScopedBehavior(USER_ID, PLACE_ID, 'like', 'shared_route_feed');

    // This is the case a naive negate-and-nudge silently fails at: when the
    // vector was built from a zero base, normalize(weight*place) is the same
    // unit vector for any positive weight, so the weight magnitude never
    // survives into the stored embedding and subtracting it back out is a
    // no-op. Resetting the row entirely is the only way to actually undo it.
    expect(tastePreferenceRepository.remove).toHaveBeenCalledWith(USER_ID);
    expect(callAiWorker).not.toHaveBeenCalled();
    expect(tastePreferenceRepository.updateFromBehavior).not.toHaveBeenCalled();
  });

  it('deletes the most recent matching row and nudges the preference vector back by the negated effective weight when other history remains', async () => {
    behaviorRepository.deleteMostRecent.mockResolvedValue({ behavior_id: 'b1' });
    // After deleting the one being undone, 0 same-action rows remain for this place --
    // but countAll being nonzero means other behavior history exists, so this
    // isn't the "only ever signal" case and should nudge rather than reset.
    behaviorRepository.countPastActions.mockResolvedValue(0);
    behaviorRepository.countAll.mockResolvedValue(1);
    tastePreferenceRepository.find.mockResolvedValue({
      embedding: [1.0, 0.0],
      source_tags: [],
      model: 'text-embedding-3-small',
      dimensions: 2,
      tag_scores: { 소금빵: 1.0 },
    });
    placeRepository.findByIds.mockResolvedValue([{ place_id: PLACE_ID, tags: [{ code: '소금빵', confidence: 1.0 }] }]);
    placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([
      { place_id: PLACE_ID, embedding: [1.0, 0.0], model: 'text-embedding-3-small', dimensions: 2 },
    ]);
    callAiWorker.mockResolvedValue({ embedding: [1.0, 0.0] });

    await reverseScopedBehavior(USER_ID, PLACE_ID, 'like', 'shared_route_feed');

    expect(behaviorRepository.deleteMostRecent).toHaveBeenCalledWith(USER_ID, PLACE_ID, 'like', 'shared_route_feed');
    expect(tastePreferenceRepository.remove).not.toHaveBeenCalled();
    // like weight 5, pastCount 0 -> damping 1, learning rate 0.15 -> 0.75, negated -> -0.75
    expect(callAiWorker).toHaveBeenCalledWith(
      '/embeddings/update-preference',
      { currentEmbedding: [1.0, 0.0], placeEmbedding: [1.0, 0.0], weight: -0.75 },
      15000
    );
    expect(tastePreferenceRepository.updateFromBehavior).toHaveBeenCalledWith(
      USER_ID,
      expect.objectContaining({ tagScores: { 소금빵: 0.25 } })
    );
  });

  it('nudges rather than resets when the user has taken the taste survey (source_tags non-empty), even with no other behavior', async () => {
    behaviorRepository.deleteMostRecent.mockResolvedValue({ behavior_id: 'b1' });
    behaviorRepository.countAll.mockResolvedValue(0);
    tastePreferenceRepository.find.mockResolvedValue({
      embedding: [1.0, 0.0],
      source_tags: ['카페'],
      model: 'text-embedding-3-small',
      dimensions: 2,
      tag_scores: {},
    });
    placeRepository.findByIds.mockResolvedValue([{ place_id: PLACE_ID, tags: [] }]);
    placeEmbeddingRepository.findByPlaceIds.mockResolvedValue([
      { place_id: PLACE_ID, embedding: [1.0, 0.0], model: 'text-embedding-3-small', dimensions: 2 },
    ]);
    callAiWorker.mockResolvedValue({ embedding: [1.0, 0.0] });

    await reverseScopedBehavior(USER_ID, PLACE_ID, 'like', 'shared_route_feed');

    expect(tastePreferenceRepository.remove).not.toHaveBeenCalled();
    expect(callAiWorker).toHaveBeenCalled();
  });
});
