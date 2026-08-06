const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateCreateFolder(req, res, next) {
  const { name } = req.body;
  if (!name || typeof name !== 'string' || !name.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty folder name is required'));
  }
  return next();
}

function validateFolderId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid folder id is required'));
  }
  return next();
}

function validateFolderBookmarkBody(req, res, next) {
  if (!isUuid(req.body.bookmarkId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid bookmarkId is required'));
  }
  return next();
}

function validateFolderBookmarkId(req, res, next) {
  if (!isUuid(req.params.bookmarkId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid bookmark id is required'));
  }
  return next();
}

module.exports = { validateCreateFolder, validateFolderId, validateFolderBookmarkBody, validateFolderBookmarkId };
