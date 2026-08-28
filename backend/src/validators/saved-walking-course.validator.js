const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

const VALID_ROUTE_TYPES = ['roundTrip', 'hotelToHotel'];
const VALID_TRANSPORT_MODES = ['car', 'walk', 'transit'];

function validateCreateSavedCourse(req, res, next) {
  const { region, routeType, transportMode, totalDistanceM, totalDurationSec, routeData } = req.body;

  if (typeof region !== 'string' || region.trim().length === 0) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty region is required'));
  }
  if (!VALID_ROUTE_TYPES.includes(routeType)) {
    return next(new AppError(400, 'INVALID_REQUEST', "routeType must be 'roundTrip' or 'hotelToHotel'"));
  }
  if (!VALID_TRANSPORT_MODES.includes(transportMode)) {
    return next(new AppError(400, 'INVALID_REQUEST', "transportMode must be 'car', 'walk', or 'transit'"));
  }
  if (totalDistanceM !== undefined && totalDistanceM !== null && typeof totalDistanceM !== 'number') {
    return next(new AppError(400, 'INVALID_REQUEST', 'totalDistanceM must be a number when provided'));
  }
  if (totalDurationSec !== undefined && totalDurationSec !== null && typeof totalDurationSec !== 'number') {
    return next(new AppError(400, 'INVALID_REQUEST', 'totalDurationSec must be a number when provided'));
  }
  if (!Array.isArray(routeData) || routeData.length === 0) {
    return next(new AppError(400, 'INVALID_REQUEST', 'routeData must be a non-empty array'));
  }
  const hasValidShape = routeData.every(
    (point) =>
      point &&
      typeof point.order === 'number' &&
      (point.type === 'hotel' || point.type === 'place') &&
      typeof point.name === 'string'
  );
  if (!hasValidShape) {
    return next(new AppError(400, 'INVALID_REQUEST', 'Each routeData point must have order, type, and name'));
  }

  return next();
}

function validateSavedCourseId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid saved course id is required'));
  }
  return next();
}

module.exports = { validateCreateSavedCourse, validateSavedCourseId };
