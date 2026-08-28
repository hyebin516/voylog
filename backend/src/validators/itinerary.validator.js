const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

const VALID_TRANSPORT_MODES = ['car', 'walk', 'transit'];

function validateCreateItinerary(req, res, next) {
  const { hotelId, placeIds, tripId, dayNumber, transportMode } = req.body;
  let { startHotelId, endHotelId } = req.body;

  // Backward compatibility: old clients send a single hotelId for a round trip.
  if (!startHotelId && !endHotelId && hotelId) {
    startHotelId = hotelId;
    endHotelId = hotelId;
    req.body.startHotelId = startHotelId;
    req.body.endHotelId = endHotelId;
  }

  if (transportMode === undefined) {
    req.body.transportMode = 'car';
  } else if (!VALID_TRANSPORT_MODES.includes(transportMode)) {
    return next(new AppError(400, 'INVALID_REQUEST', "transportMode must be 'car', 'walk', or 'transit'"));
  }

  if (!isUuid(tripId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid tripId is required'));
  }

  if (!Number.isInteger(dayNumber) || dayNumber < 1) {
    return next(new AppError(400, 'INVALID_REQUEST', 'dayNumber must be a positive integer'));
  }

  if (!isUuid(startHotelId) || !isUuid(endHotelId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'Valid startHotelId and endHotelId are required'));
  }

  if (!Array.isArray(placeIds) || placeIds.length < 2 || placeIds.length > 10 || !placeIds.every(isUuid)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'placeIds must contain between 2 and 10 valid place ids'));
  }

  return next();
}

module.exports = { validateCreateItinerary };
