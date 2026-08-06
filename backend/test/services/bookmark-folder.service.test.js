jest.mock('../../src/repositories/bookmark-folder.repository');
jest.mock('../../src/repositories/bookmark.repository');

const folderRepository = require('../../src/repositories/bookmark-folder.repository');
const bookmarkRepository = require('../../src/repositories/bookmark.repository');
const bookmarkFolderService = require('../../src/services/bookmark-folder.service');

const USER_ID = 'user-1';
const FOLDER_ID = 'folder-1';
const BOOKMARK_ID = 'bookmark-1';

afterEach(() => jest.clearAllMocks());

describe('getOwnedFolder', () => {
  it('returns the folder when it belongs to the requesting user', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: USER_ID });
    const folder = await bookmarkFolderService.getOwnedFolder(USER_ID, FOLDER_ID);
    expect(folder.folder_id).toBe(FOLDER_ID);
  });

  it('throws 404 FOLDER_NOT_FOUND when the folder does not exist', async () => {
    folderRepository.findById.mockResolvedValue(null);
    await expect(bookmarkFolderService.getOwnedFolder(USER_ID, FOLDER_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'FOLDER_NOT_FOUND',
    });
  });

  it('throws 404 FOLDER_NOT_FOUND when the folder belongs to another user', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: 'someone-else' });
    await expect(bookmarkFolderService.getOwnedFolder(USER_ID, FOLDER_ID)).rejects.toMatchObject({ statusCode: 404 });
  });
});

describe('createFolder', () => {
  it('creates a folder for the user with the given name', async () => {
    folderRepository.create.mockResolvedValue({ folder_id: FOLDER_ID, name: '제주 맛집' });
    const folder = await bookmarkFolderService.createFolder(USER_ID, '제주 맛집');
    expect(folderRepository.create).toHaveBeenCalledWith(USER_ID, '제주 맛집');
    expect(folder.name).toBe('제주 맛집');
  });
});

describe('deleteFolder', () => {
  it('soft-deletes the folder after verifying ownership', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: USER_ID });
    await bookmarkFolderService.deleteFolder(USER_ID, FOLDER_ID);
    expect(folderRepository.softDelete).toHaveBeenCalledWith(FOLDER_ID);
  });

  it('refuses to delete a folder owned by another user', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: 'someone-else' });
    await expect(bookmarkFolderService.deleteFolder(USER_ID, FOLDER_ID)).rejects.toMatchObject({ statusCode: 404 });
    expect(folderRepository.softDelete).not.toHaveBeenCalled();
  });
});

describe('addBookmarkToFolder', () => {
  it('adds the bookmark once folder and bookmark ownership are both verified', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: USER_ID });
    bookmarkRepository.findById.mockResolvedValue({ bookmark_id: BOOKMARK_ID, user_id: USER_ID });

    await bookmarkFolderService.addBookmarkToFolder(USER_ID, FOLDER_ID, BOOKMARK_ID);

    expect(folderRepository.addItem).toHaveBeenCalledWith(FOLDER_ID, BOOKMARK_ID);
  });

  it('throws 404 BOOKMARK_NOT_FOUND when the bookmark is not owned by the user', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: USER_ID });
    bookmarkRepository.findById.mockResolvedValue({ bookmark_id: BOOKMARK_ID, user_id: 'someone-else' });

    await expect(bookmarkFolderService.addBookmarkToFolder(USER_ID, FOLDER_ID, BOOKMARK_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'BOOKMARK_NOT_FOUND',
    });
    expect(folderRepository.addItem).not.toHaveBeenCalled();
  });
});

describe('removeBookmarkFromFolder', () => {
  it('removes the bookmark from the folder after verifying folder ownership', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: USER_ID });
    await bookmarkFolderService.removeBookmarkFromFolder(USER_ID, FOLDER_ID, BOOKMARK_ID);
    expect(folderRepository.removeItem).toHaveBeenCalledWith(FOLDER_ID, BOOKMARK_ID);
  });
});

describe('listBookmarksInFolder', () => {
  it('returns the bookmarks in the folder once ownership is verified', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: USER_ID });
    folderRepository.findBookmarksInFolder.mockResolvedValue([{ bookmark_id: BOOKMARK_ID }]);

    const bookmarks = await bookmarkFolderService.listBookmarksInFolder(USER_ID, FOLDER_ID);

    expect(bookmarks).toEqual([{ bookmark_id: BOOKMARK_ID }]);
  });
});
