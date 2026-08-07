jest.mock('../../src/repositories/taste-preference.repository');
jest.mock('../../src/services/aiWorkerClient');

const tastePreferenceRepository = require('../../src/repositories/taste-preference.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const tastePreferenceService = require('../../src/services/taste-preference.service');

afterEach(() => jest.clearAllMocks());

describe('getPreferences', () => {
  it('returns the saved tags when the user has preferences', async () => {
    tastePreferenceRepository.find.mockResolvedValue({ source_tags: ['소금빵', '오션뷰'] });

    const result = await tastePreferenceService.getPreferences('u1');

    expect(result).toEqual({ tags: ['소금빵', '오션뷰'] });
  });

  it('returns an empty tag list when the user has not set preferences yet', async () => {
    tastePreferenceRepository.find.mockResolvedValue(null);

    const result = await tastePreferenceService.getPreferences('u1');

    expect(result).toEqual({ tags: [] });
  });
});

describe('setPreferences', () => {
  it('embeds the joined tags and upserts the result', async () => {
    callAiWorker.mockResolvedValue({ embedding: [0.1, 0.2], model: 'text-embedding-3-small', dimensions: 2 });
    tastePreferenceRepository.upsert.mockResolvedValue({ source_tags: ['소금빵', '오션뷰'] });

    const result = await tastePreferenceService.setPreferences('u1', ['소금빵', '오션뷰']);

    expect(callAiWorker).toHaveBeenCalledWith('/embeddings/generate', { text: '소금빵, 오션뷰' }, 15000);
    expect(tastePreferenceRepository.upsert).toHaveBeenCalledWith('u1', {
      embedding: [0.1, 0.2],
      sourceTags: ['소금빵', '오션뷰'],
      sourceText: '소금빵, 오션뷰',
      model: 'text-embedding-3-small',
      dimensions: 2,
    });
    expect(result).toEqual({ tags: ['소금빵', '오션뷰'] });
  });
});

describe('clearPreferences', () => {
  it('removes the saved preference row', async () => {
    await tastePreferenceService.clearPreferences('u1');

    expect(tastePreferenceRepository.remove).toHaveBeenCalledWith('u1');
  });
});
