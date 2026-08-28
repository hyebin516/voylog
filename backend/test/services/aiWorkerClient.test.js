jest.mock('axios');

describe('callAiWorker', () => {
  let mockPost;
  let callAiWorker;

  beforeEach(() => {
    jest.resetModules();
    const axios = require('axios');
    mockPost = jest.fn();
    axios.create.mockReturnValue({ post: mockPost });
    ({ callAiWorker } = require('../../src/services/aiWorkerClient'));
  });

  it('returns the response data on success', async () => {
    mockPost.mockResolvedValue({ data: { ok: true } });

    const result = await callAiWorker('/foo', { a: 1 }, 1000);

    expect(result).toEqual({ ok: true });
    expect(mockPost).toHaveBeenCalledWith('/foo', { a: 1 }, { timeout: 1000 });
  });

  it('maps a 422 response to TRANSCRIPT_NOT_FOUND regardless of its body', async () => {
    mockPost.mockRejectedValue({ response: { status: 422, data: {} } });

    await expect(callAiWorker('/x', {}, 1000)).rejects.toMatchObject({
      statusCode: 422,
      code: 'TRANSCRIPT_NOT_FOUND',
    });
  });

  it("forwards the AI worker's own status/code/message when the error body has one", async () => {
    mockPost.mockRejectedValue({
      response: { status: 503, data: { error: { code: 'GEOCODING_FAILED', message: '지역을 찾을 수 없어요' } } },
    });

    await expect(callAiWorker('/x', {}, 1000)).rejects.toMatchObject({
      statusCode: 503,
      code: 'GEOCODING_FAILED',
      message: '지역을 찾을 수 없어요',
    });
  });

  it('falls back to a generic AI_PROVIDER_ERROR when there is no structured error body (e.g. network failure)', async () => {
    mockPost.mockRejectedValue(new Error('ECONNREFUSED'));

    await expect(callAiWorker('/x', {}, 1000)).rejects.toMatchObject({
      statusCode: 503,
      code: 'AI_PROVIDER_ERROR',
    });
  });
});
