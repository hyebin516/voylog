const {
  validateCreateFolder,
  validateFolderId,
  validateFolderBookmarkBody,
  validateFolderBookmarkId,
} = require('../../src/validators/bookmark-folder.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_UUID = '5ad1f447-a1e2-46a0-8093-0d007ff3071d';

describe('validateCreateFolder', () => {
  it('passes for a non-empty name', () => {
    const next = jest.fn();
    validateCreateFolder(mockReq({ body: { name: '제주 맛집' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing name', () => {
    const next = jest.fn();
    validateCreateFolder(mockReq({ body: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a whitespace-only name', () => {
    const next = jest.fn();
    validateCreateFolder(mockReq({ body: { name: '   ' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateFolderId', () => {
  it('passes for a valid uuid param', () => {
    const next = jest.fn();
    validateFolderId(mockReq({ params: { id: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a non-uuid param', () => {
    const next = jest.fn();
    validateFolderId(mockReq({ params: { id: 'nope' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateFolderBookmarkBody', () => {
  it('passes for a valid uuid bookmarkId', () => {
    const next = jest.fn();
    validateFolderBookmarkBody(mockReq({ body: { bookmarkId: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing bookmarkId', () => {
    const next = jest.fn();
    validateFolderBookmarkBody(mockReq({ body: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateFolderBookmarkId', () => {
  it('passes for a valid uuid param', () => {
    const next = jest.fn();
    validateFolderBookmarkId(mockReq({ params: { bookmarkId: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a non-uuid param', () => {
    const next = jest.fn();
    validateFolderBookmarkId(mockReq({ params: { bookmarkId: 'nope' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
