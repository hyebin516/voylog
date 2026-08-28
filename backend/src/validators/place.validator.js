const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validatePlaceId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid place id is required'));
  }
  return next();
}

module.exports = { validatePlaceId };
