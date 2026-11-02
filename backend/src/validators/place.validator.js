const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validatePlaceId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid place id is required'));
  }
  return next();
}

function validatePlaceSearch(req, res, next) {
  const query = req.query.query;
  if (typeof query !== 'string' || query.trim().length === 0) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty query is required'));
  }
  return next();
}

module.exports = {
  validatePlaceSearch, validatePlaceId };
