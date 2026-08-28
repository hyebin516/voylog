jest.mock('../../src/repositories/place.repository');
jest.mock('../../src/services/aiWorkerClient');

const placeRepository = require('../../src/repositories/place.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { getPlaceSummary } = require('../../src/services/place-summary.service');

const PLACE_ID = 'place-1';

afterEach(() => jest.clearAllMocks());

describe('getPlaceSummary', () => {
  it('throws 404 PLACE_NOT_FOUND when the place does not exist', async () => {
    placeRepository.findById.mockResolvedValue(null);

    await expect(getPlaceSummary(PLACE_ID)).rejects.toMatchObject({ statusCode: 404, code: 'PLACE_NOT_FOUND' });
  });

  it('returns unavailable when the place has no coordinates', async () => {
    placeRepository.findById.mockResolvedValue({ place_id: PLACE_ID, latitude: null, longitude: null });

    const result = await getPlaceSummary(PLACE_ID);

    expect(result).toEqual({ available: false, pros: null, cons: null, sourceCount: 0 });
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('returns unavailable when fewer than 2 videos mention the place', async () => {
    placeRepository.findById.mockResolvedValue({ place_id: PLACE_ID, latitude: 37.5, longitude: 127.0 });
    placeRepository.findSummarySources.mockResolvedValue([{ videoId: 'v1', mentionNote: '뷰가 좋다' }]);

    const result = await getPlaceSummary(PLACE_ID);

    expect(result).toEqual({ available: false, pros: null, cons: null, sourceCount: 1 });
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('calls the AI worker and caches the summary when there is no cache yet', async () => {
    placeRepository.findById.mockResolvedValue({
      place_id: PLACE_ID,
      name: '해운대해수욕장',
      latitude: 37.5,
      longitude: 127.0,
      summary_source_count: null,
      summary_generated_at: null,
    });
    placeRepository.findSummarySources.mockResolvedValue([
      { videoId: 'v1', mentionNote: '뷰가 좋다' },
      { videoId: 'v2', mentionNote: '웨이팅이 길다' },
    ]);
    callAiWorker.mockResolvedValue({ pros: '뷰가 좋다는 평이 많아요.', cons: '웨이팅이 길다는 평이 많아요.' });

    const result = await getPlaceSummary(PLACE_ID);

    expect(callAiWorker).toHaveBeenCalledWith(
      '/places/summarize',
      { placeName: '해운대해수욕장', notes: ['뷰가 좋다', '웨이팅이 길다'], llmProvider: 'auto' },
      20000
    );
    expect(placeRepository.updateSummary).toHaveBeenCalledWith(PLACE_ID, {
      prosSummary: '뷰가 좋다는 평이 많아요.',
      consSummary: '웨이팅이 길다는 평이 많아요.',
      summarySourceCount: 2,
    });
    expect(result).toEqual({
      available: true,
      pros: '뷰가 좋다는 평이 많아요.',
      cons: '웨이팅이 길다는 평이 많아요.',
      sourceCount: 2,
    });
  });

  it('returns the cached summary without calling the AI worker when the source count is unchanged', async () => {
    placeRepository.findById.mockResolvedValue({
      place_id: PLACE_ID,
      latitude: 37.5,
      longitude: 127.0,
      pros_summary: '뷰가 좋다는 평이 많아요.',
      cons_summary: '웨이팅이 길다는 평이 많아요.',
      summary_source_count: 2,
      summary_generated_at: new Date(),
    });
    placeRepository.findSummarySources.mockResolvedValue([
      { videoId: 'v1', mentionNote: '뷰가 좋다' },
      { videoId: 'v2', mentionNote: '웨이팅이 길다' },
    ]);

    const result = await getPlaceSummary(PLACE_ID);

    expect(callAiWorker).not.toHaveBeenCalled();
    expect(result).toEqual({
      available: true,
      pros: '뷰가 좋다는 평이 많아요.',
      cons: '웨이팅이 길다는 평이 많아요.',
      sourceCount: 2,
    });
  });

  it('regenerates the summary when a new video has added a mention since it was cached', async () => {
    placeRepository.findById.mockResolvedValue({
      place_id: PLACE_ID,
      name: '해운대해수욕장',
      latitude: 37.5,
      longitude: 127.0,
      pros_summary: '뷰가 좋다는 평이 많아요.',
      cons_summary: '웨이팅이 길다는 평이 많아요.',
      summary_source_count: 2,
      summary_generated_at: new Date(),
    });
    placeRepository.findSummarySources.mockResolvedValue([
      { videoId: 'v1', mentionNote: '뷰가 좋다' },
      { videoId: 'v2', mentionNote: '웨이팅이 길다' },
      { videoId: 'v3', mentionNote: '주차가 편하다' },
    ]);
    callAiWorker.mockResolvedValue({ pros: '뷰와 주차가 좋다는 평이 많아요.', cons: '웨이팅이 길다는 평이 많아요.' });

    const result = await getPlaceSummary(PLACE_ID);

    expect(callAiWorker).toHaveBeenCalled();
    expect(result.sourceCount).toBe(3);
  });
});
