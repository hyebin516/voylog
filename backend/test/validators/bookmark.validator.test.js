const { validateCreateBookmark, validateBookmarkId } = require('../../src/validators/bookmark.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_UUID = '5ad1f447-a1e2-46a0-8093-0d007ff3071d';

describe('validateCreateBookmark', () => {
  it('passes for a valid placeId', () => {
    const next = jest.fn();
    validateCreateBookmark(mockReq({ body: { placeId: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing placeId', () => {
    const next = jest.fn();
    validateCreateBookmark(mockReq({ body: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
    expect(next.mock.calls[0][0].statusCode).toBe(400);
  });

  it('rejects a non-uuid placeId', () => {
    const next = jest.fn();
    validateCreateBookmark(mockReq({ body: { placeId: 'nope' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateBookmarkId', () => {
  it('passes for a valid uuid param', () => {
    const next = jest.fn();
    validateBookmarkId(mockReq({ params: { id: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a non-uuid param', () => {
    const next = jest.fn();
    validateBookmarkId(mockReq({ params: { id: 'nope' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
