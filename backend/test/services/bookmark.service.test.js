jest.mock('../../src/repositories/bookmark.repository');

const bookmarkRepository = require('../../src/repositories/bookmark.repository');
const bookmarkService = require('../../src/services/bookmark.service');
const AppError = require('../../src/utils/AppError');

const USER_ID = 'user-1';
const PLACE_ID = 'place-1';

afterEach(() => jest.clearAllMocks());

describe('addBookmark', () => {
  it('creates a bookmark when none exists yet', async () => {
    bookmarkRepository.findByUserAndPlace.mockResolvedValue(null);
    bookmarkRepository.create.mockResolvedValue({ bookmark_id: 'b1', user_id: USER_ID, place_id: PLACE_ID });

    const result = await bookmarkService.addBookmark(USER_ID, PLACE_ID);

    expect(bookmarkRepository.create).toHaveBeenCalledWith(USER_ID, PLACE_ID);
    expect(result.bookmark_id).toBe('b1');
  });

  it('throws 409 BOOKMARK_EXISTS when already bookmarked (unique user_id+place_id)', async () => {
    bookmarkRepository.findByUserAndPlace.mockResolvedValue({ bookmark_id: 'existing' });

    await expect(bookmarkService.addBookmark(USER_ID, PLACE_ID)).rejects.toMatchObject({
      statusCode: 409,
      code: 'BOOKMARK_EXISTS',
    });
    expect(bookmarkRepository.create).not.toHaveBeenCalled();
  });
});

describe('removeBookmark', () => {
  it('removes a bookmark owned by the requesting user', async () => {
    bookmarkRepository.findById.mockResolvedValue({ bookmark_id: 'b1', user_id: USER_ID });

    await bookmarkService.removeBookmark(USER_ID, 'b1');

    expect(bookmarkRepository.remove).toHaveBeenCalledWith('b1');
  });

  it('throws 404 when the bookmark does not exist', async () => {
    bookmarkRepository.findById.mockResolvedValue(null);

    await expect(bookmarkService.removeBookmark(USER_ID, 'missing')).rejects.toBeInstanceOf(AppError);
    expect(bookmarkRepository.remove).not.toHaveBeenCalled();
  });

  it('throws 404 when the bookmark belongs to a different user (no cross-user deletion)', async () => {
    bookmarkRepository.findById.mockResolvedValue({ bookmark_id: 'b1', user_id: 'someone-else' });

    await expect(bookmarkService.removeBookmark(USER_ID, 'b1')).rejects.toMatchObject({
      statusCode: 404,
      code: 'BOOKMARK_NOT_FOUND',
    });
    expect(bookmarkRepository.remove).not.toHaveBeenCalled();
  });
});
