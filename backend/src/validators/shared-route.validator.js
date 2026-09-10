const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateSharedRouteId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid shared route id is required'));
  }
  return next();
}

function validatePublishTitle(req, res, next) {
  const { title } = req.body;
  if (typeof title !== 'string' || title.trim().length === 0 || title.length > 100) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty title of at most 100 characters is required'));
  }
  return next();
}

module.exports = { validateSharedRouteId, validatePublishTitle };
