const AppError = require('../utils/AppError');

const MAX_RADIUS_M = 5000;
const MAX_LIMIT = 20;

function validateNearbyRequest(req, res, next) {
  const { latitude, longitude, localTime, radiusMeters, limit } = req.body;

  if (typeof latitude !== 'number' || latitude < -90 || latitude > 90) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid latitude is required'));
  }
  if (typeof longitude !== 'number' || longitude < -180 || longitude > 180) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid longitude is required'));
  }
  if (typeof localTime !== 'string' || Number.isNaN(Date.parse(localTime))) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid ISO 8601 localTime is required'));
  }
  if (radiusMeters !== undefined && (typeof radiusMeters !== 'number' || radiusMeters <= 0 || radiusMeters > MAX_RADIUS_M)) {
    return next(new AppError(400, 'INVALID_REQUEST', `radiusMeters must be between 1 and ${MAX_RADIUS_M}`));
  }
  if (limit !== undefined && (typeof limit !== 'number' || limit <= 0 || limit > MAX_LIMIT)) {
    return next(new AppError(400, 'INVALID_REQUEST', `limit must be between 1 and ${MAX_LIMIT}`));
  }
  return next();
}

function validateWalkingCourseRequest(req, res, next) {
  const { region, localTime } = req.body;

  if (typeof region !== 'string' || region.trim().length === 0) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty region is required'));
  }
  if (typeof localTime !== 'string' || Number.isNaN(Date.parse(localTime))) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid ISO 8601 localTime is required'));
  }
  return next();
}

module.exports = { validateNearbyRequest, validateWalkingCourseRequest };
