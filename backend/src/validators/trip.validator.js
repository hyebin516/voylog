const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateCreateTrip(req, res, next) {
  const { name } = req.body;
  if (!name || typeof name !== 'string' || !name.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty trip name is required'));
  }
  return next();
}

function validateTripId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid trip id is required'));
  }
  return next();
}

module.exports = { validateCreateTrip, validateTripId };
