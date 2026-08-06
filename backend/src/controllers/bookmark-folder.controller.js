const bookmarkFolderService = require('../services/bookmark-folder.service');
const { toBookmarkedPlaceResponse } = require('./bookmark.controller');
const { success } = require('../utils/response');

function toFolderResponse(folder) {
  return {
    folderId: folder.folder_id,
    name: folder.name,
    bookmarkCount: folder.bookmark_count,
    createdAt: folder.created_at,
  };
}

async function create(req, res, next) {
  try {
    const folder = await bookmarkFolderService.createFolder(req.user.userId, req.body.name);
    return success(res, { folderId: folder.folder_id, name: folder.name, createdAt: folder.created_at }, 201);
  } catch (err) {
    return next(err);
  }
}

async function list(req, res, next) {
  try {
    const folders = await bookmarkFolderService.listFolders(req.user.userId);
    return success(res, { folders: folders.map(toFolderResponse) });
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    await bookmarkFolderService.deleteFolder(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

async function addBookmark(req, res, next) {
  try {
    await bookmarkFolderService.addBookmarkToFolder(req.user.userId, req.params.id, req.body.bookmarkId);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

async function removeBookmark(req, res, next) {
  try {
    await bookmarkFolderService.removeBookmarkFromFolder(req.user.userId, req.params.id, req.params.bookmarkId);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

async function listBookmarks(req, res, next) {
  try {
    const bookmarks = await bookmarkFolderService.listBookmarksInFolder(req.user.userId, req.params.id);
    return success(res, { bookmarks: bookmarks.map(toBookmarkedPlaceResponse) });
  } catch (err) {
    return next(err);
  }
}

module.exports = { create, list, remove, addBookmark, removeBookmark, listBookmarks };
