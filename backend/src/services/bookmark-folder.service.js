const folderRepository = require('../repositories/bookmark-folder.repository');
const bookmarkRepository = require('../repositories/bookmark.repository');
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

module.exports = {
  getOwnedFolder,
  createFolder,
  listFolders,
  deleteFolder,
  addBookmarkToFolder,
  removeBookmarkFromFolder,
  listBookmarksInFolder,
};
