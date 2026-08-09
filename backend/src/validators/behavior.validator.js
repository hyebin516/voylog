const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');
const { isValidAction, BEHAVIOR_WEIGHTS } = require('../services/behavior-scoring-policy');

function validateRecordBehavior(req, res, next) {
  const { placeId, action, screen, distanceMeters } = req.body;

  if (!isUuid(placeId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid placeId is required'));
  }
  if (typeof action !== 'string' || !isValidAction(action)) {
    return next(
      new AppError(400, 'INVALID_REQUEST', `action must be one of: ${Object.keys(BEHAVIOR_WEIGHTS).join(', ')}`)
    );
  }
  if (screen !== undefined && typeof screen !== 'string') {
    return next(new AppError(400, 'INVALID_REQUEST', 'screen must be a string'));
  }
  if (distanceMeters !== undefined && (typeof distanceMeters !== 'number' || distanceMeters < 0)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'distanceMeters must be a non-negative number'));
  }
  return next();
}

module.exports = { validateRecordBehavior };
