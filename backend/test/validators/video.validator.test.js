const { validateAnalyzeRequest, validateSearchRequest } = require('../../src/validators/video.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

describe('validateAnalyzeRequest', () => {
  it('calls next() with no error for a valid watch url', () => {
    const req = mockReq({ body: { youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' } });
    const next = jest.fn();
    validateAnalyzeRequest(req, mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('calls next() with no error for a valid youtu.be url', () => {
    const req = mockReq({ body: { youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ' } });
    const next = jest.fn();
    validateAnalyzeRequest(req, mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing youtubeUrl with 400 INVALID_URL', () => {
    const req = mockReq({ body: {} });
    const next = jest.fn();
    validateAnalyzeRequest(req, mockRes(), next);
    const err = next.mock.calls[0][0];
    expect(err).toBeInstanceOf(AppError);
    expect(err.statusCode).toBe(400);
    expect(err.code).toBe('INVALID_URL');
  });

  it('rejects a non-youtube url', () => {
    const req = mockReq({ body: { youtubeUrl: 'https://example.com/video' } });
    const next = jest.fn();
    validateAnalyzeRequest(req, mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateSearchRequest', () => {
  it('passes for a non-empty hashtag', () => {
    const next = jest.fn();
    validateSearchRequest(mockReq({ query: { hashtag: '부산여행' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing hashtag', () => {
    const next = jest.fn();
    validateSearchRequest(mockReq({ query: {} }), mockRes(), next);
    const err = next.mock.calls[0][0];
    expect(err).toBeInstanceOf(AppError);
    expect(err.statusCode).toBe(400);
  });

  it('rejects a whitespace-only hashtag', () => {
    const next = jest.fn();
    validateSearchRequest(mockReq({ query: { hashtag: '   ' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
