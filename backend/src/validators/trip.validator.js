const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function isValidOptionalDate(value) {
  return value === undefined || value === null || (typeof value === 'string' && ISO_DATE_PATTERN.test(value));
}

function validateCreateTrip(req, res, next) {
  const { name, startDate, endDate } = req.body;
  if (!name || typeof name !== 'string' || !name.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty trip name is required'));
  }
  if (!isValidOptionalDate(startDate) || !isValidOptionalDate(endDate)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'startDate/endDate must be ISO dates (YYYY-MM-DD)'));
  }
  if (startDate && endDate && startDate > endDate) {
    return next(new AppError(400, 'INVALID_REQUEST', 'startDate must not be after endDate'));
  }
  return next();
}

function validateTripId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid trip id is required'));
  }
  return next();
}

function validateUpdateTripDates(req, res, next) {
  const { startDate, endDate } = req.body;
  if (!ISO_DATE_PATTERN.test(startDate || '') || !ISO_DATE_PATTERN.test(endDate || '')) {
    return next(new AppError(400, 'INVALID_REQUEST', 'startDate/endDate are required ISO dates (YYYY-MM-DD)'));
  }
  if (startDate > endDate) {
    return next(new AppError(400, 'INVALID_REQUEST', 'startDate must not be after endDate'));
  }
  return next();
}

module.exports = { validateCreateTrip, validateTripId, validateUpdateTripDates };
