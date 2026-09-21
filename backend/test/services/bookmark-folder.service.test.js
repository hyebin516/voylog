jest.mock('../../src/repositories/bookmark-folder.repository');
jest.mock('../../src/repositories/bookmark.repository');
jest.mock('../../src/services/aiWorkerClient');

const folderRepository = require('../../src/repositories/bookmark-folder.repository');
const bookmarkRepository = require('../../src/repositories/bookmark.repository');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
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

describe('createRouteFromFolder', () => {
  function bookmarkedPlace(id, latitude, longitude) {
    return { bookmark_id: `b-${id}`, place_id: id, name: id, latitude, longitude };
  }

  beforeEach(() => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: USER_ID, name: '부산 코스' });
    callAiWorker.mockResolvedValue({ routeType: 'placeToPlace', transportMode: 'mixed', optimizedRoute: [] });
  });

  it('asks for the quickest place-to-place route, with no hotel or centre point', async () => {
    folderRepository.findBookmarksInFolder.mockResolvedValue([
      bookmarkedPlace('p1', '35.10', '129.00'),
      bookmarkedPlace('p2', '35.12', '129.04'),
    ]);

    const result = await bookmarkFolderService.createRouteFromFolder(USER_ID, FOLDER_ID);

    // Only the places go to the optimizer: it picks the first and last stop
    // and whether each leg is walked or driven.
    expect(callAiWorker).toHaveBeenCalledWith(
      '/optimize-place-route',
      {
        places: [
          { placeId: 'p1', name: 'p1', latitude: 35.1, longitude: 129.0 },
          { placeId: 'p2', name: 'p2', latitude: 35.12, longitude: 129.04 },
        ],
      },
      30000
    );
    expect(result).toEqual({
      course: { routeType: 'placeToPlace', transportMode: 'mixed', optimizedRoute: [] },
      recommendations: [],
    });
  });

  it('leaves out bookmarks that never got coordinates', async () => {
    folderRepository.findBookmarksInFolder.mockResolvedValue([
      bookmarkedPlace('p1', '35.10', '129.00'),
      bookmarkedPlace('p2', null, null),
      bookmarkedPlace('p3', '35.12', '129.04'),
    ]);

    await bookmarkFolderService.createRouteFromFolder(USER_ID, FOLDER_ID);

    expect(callAiWorker.mock.calls[0][1].places.map((p) => p.placeId)).toEqual(['p1', 'p3']);
  });

  it('refuses when fewer than 2 places can be routed', async () => {
    folderRepository.findBookmarksInFolder.mockResolvedValue([
      bookmarkedPlace('p1', '35.10', '129.00'),
      bookmarkedPlace('p2', null, null),
    ]);

    await expect(bookmarkFolderService.createRouteFromFolder(USER_ID, FOLDER_ID)).rejects.toMatchObject({
      statusCode: 400,
      code: 'INVALID_REQUEST',
    });
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('caps the route at the 10 places the optimizer takes', async () => {
    folderRepository.findBookmarksInFolder.mockResolvedValue(
      Array.from({ length: 14 }, (_, i) => bookmarkedPlace(`p${i}`, '35.10', '129.00'))
    );

    await bookmarkFolderService.createRouteFromFolder(USER_ID, FOLDER_ID);

    expect(callAiWorker.mock.calls[0][1].places).toHaveLength(10);
  });

  it("refuses another user's folder", async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: FOLDER_ID, user_id: 'someone-else' });

    await expect(bookmarkFolderService.createRouteFromFolder(USER_ID, FOLDER_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'FOLDER_NOT_FOUND',
    });
  });
});
