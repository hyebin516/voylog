const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateCreateBookmark(req, res, next) {
  const { placeId } = req.body;
  if (!isUuid(placeId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid placeId is required'));
  }
  return next();
}

function validateBookmarkId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid bookmark id is required'));
  }
  return next();
}

module.exports = { validateCreateBookmark, validateBookmarkId };
