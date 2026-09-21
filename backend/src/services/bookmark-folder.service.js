const folderRepository = require('../repositories/bookmark-folder.repository');
const bookmarkRepository = require('../repositories/bookmark.repository');
const { callAiWorker } = require('./aiWorkerClient');
const AppError = require('../utils/AppError');

async function getOwnedFolder(userId, folderId) {
  const folder = await folderRepository.findById(folderId);
  if (!folder || folder.user_id !== userId) {
    throw new AppError(404, 'FOLDER_NOT_FOUND', 'Bookmark folder not found');
  }
  return folder;
}

async function getOwnedBookmark(userId, bookmarkId) {
  const bookmark = await bookmarkRepository.findById(bookmarkId);
  if (!bookmark || bookmark.user_id !== userId) {
    throw new AppError(404, 'BOOKMARK_NOT_FOUND', 'Bookmark not found');
  }
  return bookmark;
}

async function createFolder(userId, name) {
  return folderRepository.create(userId, name);
}

async function listFolders(userId) {
  return folderRepository.findAllByUser(userId);
}

async function deleteFolder(userId, folderId) {
  await getOwnedFolder(userId, folderId);
  await folderRepository.softDelete(folderId);
}

async function addBookmarkToFolder(userId, folderId, bookmarkId) {
  await getOwnedFolder(userId, folderId);
  await getOwnedBookmark(userId, bookmarkId);
  await folderRepository.addItem(folderId, bookmarkId);
}

async function removeBookmarkFromFolder(userId, folderId, bookmarkId) {
  await getOwnedFolder(userId, folderId);
  await folderRepository.removeItem(folderId, bookmarkId);
}

async function listBookmarksInFolder(userId, folderId) {
  await getOwnedFolder(userId, folderId);
  return folderRepository.findBookmarksInFolder(folderId);
}

// Enough stops to be a route at all, and the ceiling the optimizer works
// within -- same bounds as a trip day's route (FR-07).
const MIN_ROUTE_PLACES = 2;
const MAX_ROUTE_PLACES = 10;

/**
 * Builds a route straight from a folder's bookmarks (FR-11): no hotel and no
 * trip, the folder itself is the plan.
 *
 * The AI Worker orders the places for the least total travel time as an
 * open path -- first and last stop are whichever places make that shortest,
 * not a loop back to some centre point -- and each leg is walked when that
 * takes at most 15 minutes, otherwise taken by bus when there is one (with
 * the bus number and stops). A pure walking route had folders spanning a
 * city asking for hour-long walks between stops.
 * Places without coordinates can't be routed through and are left out.
 */
async function createRouteFromFolder(userId, folderId) {
  await getOwnedFolder(userId, folderId);
  const bookmarks = await folderRepository.findBookmarksInFolder(folderId);

  const places = bookmarks
    .filter((b) => b.latitude != null && b.longitude != null)
    .slice(0, MAX_ROUTE_PLACES)
    .map((b) => ({
      placeId: b.place_id,
      name: b.name,
      latitude: Number(b.latitude),
      longitude: Number(b.longitude),
    }));

  if (places.length < MIN_ROUTE_PLACES) {
    throw new AppError(
      400,
      'INVALID_REQUEST',
      'A route needs at least 2 bookmarked places with coordinates'
    );
  }

  const route = await callAiWorker('/optimize-place-route', { places }, 30000);

  // Shaped like the 뚜벅이 코스 result so the app renders it with the same
  // screen. `recommendations` stays empty: these places were chosen by the
  // user, not scored by us, so there is nothing to explain.
  return { course: route, recommendations: [] };
}

module.exports = {
  getOwnedFolder,
  createRouteFromFolder,
  createFolder,
  listFolders,
  deleteFolder,
  addBookmarkToFolder,
  removeBookmarkFromFolder,
  listBookmarksInFolder,
};
