const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateCreateItinerary(req, res, next) {
  const { hotelId, placeIds } = req.body;
  let { startHotelId, endHotelId } = req.body;

  // Backward compatibility: old clients send a single hotelId for a round trip.
  if (!startHotelId && !endHotelId && hotelId) {
    startHotelId = hotelId;
    endHotelId = hotelId;
    req.body.startHotelId = startHotelId;
    req.body.endHotelId = endHotelId;
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
