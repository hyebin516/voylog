const bookmarkRepository = require('../repositories/bookmark.repository');
const AppError = require('../utils/AppError');

async function addBookmark(userId, placeId) {
  const existing = await bookmarkRepository.findByUserAndPlace(userId, placeId);
  if (existing) {
    throw new AppError(409, 'BOOKMARK_EXISTS', 'This place is already bookmarked');
  }
  return bookmarkRepository.create(userId, placeId);
}

async function listBookmarks(userId) {
  return bookmarkRepository.findAllByUser(userId);
}

async function removeBookmark(userId, bookmarkId) {
  const bookmark = await bookmarkRepository.findById(bookmarkId);
  if (!bookmark || bookmark.user_id !== userId) {
    throw new AppError(404, 'BOOKMARK_NOT_FOUND', 'Bookmark not found');
  }
  await bookmarkRepository.remove(bookmarkId);
}

module.exports = { addBookmark, listBookmarks, removeBookmark };
