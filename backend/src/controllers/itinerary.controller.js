const itineraryService = require('../services/itinerary.service');
const { success } = require('../utils/response');

function toItineraryResponse(itinerary) {
  return {
    itineraryId: itinerary.itinerary_id,
    startHotelId: itinerary.start_hotel_id,
    endHotelId: itinerary.end_hotel_id,
    routeType: itinerary.route_type,
    optimizationPriority: itinerary.optimization_priority,
    totalDistanceM: itinerary.total_distance_m,
    totalDurationSec: itinerary.total_duration_sec,
    routeData: itinerary.route_data,
    createdAt: itinerary.created_at,
  };
}

async function create(req, res, next) {
  try {
    const { startHotelId, endHotelId, placeIds } = req.body;
    const itinerary = await itineraryService.createItinerary(req.user.userId, startHotelId, endHotelId, placeIds);
    return success(res, toItineraryResponse(itinerary), 201);
  } catch (err) {
    return next(err);
  }
}

module.exports = { create };
