const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateCreateHotel(req, res, next) {
  const { name, address, latitude, longitude } = req.body;
  if (!name || !address || typeof latitude !== 'number' || typeof longitude !== 'number') {
    return next(new AppError(400, 'INVALID_REQUEST', 'name, address, latitude, and longitude are required'));
  }
  return next();
}

function validateHotelId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid hotel id is required'));
  }
  return next();
}

function validateHotelSearchQuery(req, res, next) {
  if (typeof req.query.query !== 'string' || !req.query.query.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty query is required'));
  }
  return next();
}

function validateReverseGeocodeQuery(req, res, next) {
  const latitude = Number(req.query.latitude);
  const longitude = Number(req.query.longitude);
  if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'latitude and longitude are required'));
  }
  return next();
}

module.exports = {
  validateCreateHotel,
  validateHotelId,
  validateHotelSearchQuery,
  validateReverseGeocodeQuery,
};
