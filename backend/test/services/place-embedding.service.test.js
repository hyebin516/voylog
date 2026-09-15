jest.mock('../../src/repositories/place-embedding.repository');
jest.mock('../../src/services/aiWorkerClient');

const placeEmbeddingRepository = require('../../src/repositories/place-embedding.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { ensurePlaceEmbeddings } = require('../../src/services/place-embedding.service');

afterEach(() => jest.clearAllMocks());

describe('ensurePlaceEmbeddings', () => {
  it('returns the places untouched without calling the AI worker when all are embedded', async () => {
    const places = [{ place_id: 'p1', name: 'A', embedding: [1, 0] }];

    await expect(ensurePlaceEmbeddings(places)).resolves.toBe(places);
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('embeds only the missing places in one batch call and stores them', async () => {
    callAiWorker.mockResolvedValue({ embeddings: [[0.5, 0.5]], model: 'm', dimensions: 2 });
    placeEmbeddingRepository.upsertMany.mockResolvedValue();

    const result = await ensurePlaceEmbeddings([
      { place_id: 'p1', name: 'A', embedding: [1, 0] },
      { place_id: 'p2', name: '카페', category: 'cafe', address: '서울', embedding: null },
    ]);

    expect(callAiWorker).toHaveBeenCalledWith('/embeddings/generate-batch', { texts: ['카페 | cafe | 서울'] }, 20000);
    expect(placeEmbeddingRepository.upsertMany).toHaveBeenCalledWith([
      expect.objectContaining({ placeId: 'p2', embedding: [0.5, 0.5], model: 'm', dimensions: 2 }),
    ]);
    expect(result.map((p) => p.embedding)).toEqual([[1, 0], [0.5, 0.5]]);
  });

  it('splits more than 200 missing places into several batches', async () => {
    callAiWorker.mockImplementation(async (path, { texts }) => ({
      embeddings: texts.map(() => [1]),
      model: 'm',
      dimensions: 1,
    }));
    const places = Array.from({ length: 250 }, (_, i) => ({ place_id: `p${i}`, name: `n${i}`, embedding: null }));

    const result = await ensurePlaceEmbeddings(places);

    expect(callAiWorker).toHaveBeenCalledTimes(2);
    expect(callAiWorker.mock.calls[1][1].texts).toHaveLength(50);
    expect(result.every((p) => p.embedding)).toBe(true);
  });

  it('returns the places without embeddings when generation fails', async () => {
    callAiWorker.mockRejectedValue(new Error('AI_PROVIDER_ERROR'));
    const places = [{ place_id: 'p1', name: 'A', embedding: null }];

    await expect(ensurePlaceEmbeddings(places)).resolves.toEqual(places);
    expect(placeEmbeddingRepository.upsertMany).not.toHaveBeenCalled();
  });
});
