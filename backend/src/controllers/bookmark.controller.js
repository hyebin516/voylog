const bookmarkService = require('../services/bookmark.service');
const { success } = require('../utils/response');

function toBookmarkResponse(bookmark) {
  return {
    bookmarkId: bookmark.bookmark_id,
    placeId: bookmark.place_id,
    createdAt: bookmark.created_at,
  };
}

function toBookmarkedPlaceResponse(row) {
  return {
    bookmarkId: row.bookmark_id,
    bookmarkedAt: row.created_at,
    placeId: row.place_id,
    videoId: row.video_id,
    name: row.name,
    address: row.address,
    latitude: row.latitude != null ? Number(row.latitude) : null,
    longitude: row.longitude != null ? Number(row.longitude) : null,
    timestampSec: row.timestamp_sec,
    source: row.source,
    confidence: Number(row.confidence),
  };
}

async function create(req, res, next) {
  try {
    const bookmark = await bookmarkService.addBookmark(req.user.userId, req.body.placeId);
    return success(res, toBookmarkResponse(bookmark), 201);
  } catch (err) {
    return next(err);
  }
}

async function list(req, res, next) {
  try {
    const bookmarks = await bookmarkService.listBookmarks(req.user.userId);
    return success(res, { bookmarks: bookmarks.map(toBookmarkedPlaceResponse) });
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    await bookmarkService.removeBookmark(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { create, list, remove };
