const itineraryService = require('../services/itinerary.service');
const { toPublishedRouteResponse } = require('./shared-route.controller');
const { success } = require('../utils/response');

function toItineraryResponse(itinerary) {
  return {
    itineraryId: itinerary.itinerary_id,
    tripId: itinerary.trip_id,
    dayNumber: itinerary.day_number,
    startHotelId: itinerary.start_hotel_id,
    endHotelId: itinerary.end_hotel_id,
    routeType: itinerary.route_type,
    optimizationPriority: itinerary.optimization_priority,
    transportMode: itinerary.transport_mode,
    totalDistanceM: itinerary.total_distance_m,
    totalDurationSec: itinerary.total_duration_sec,
    routeData: itinerary.route_data,
    createdAt: itinerary.created_at,
  };
}

async function create(req, res, next) {
  try {
    const { tripId, dayNumber, startHotelId, endHotelId, placeIds, transportMode } = req.body;
    const itinerary = await itineraryService.createItinerary(
      req.user.userId,
      tripId,
      dayNumber,
      startHotelId,
      endHotelId,
      placeIds,
      transportMode
    );
    return success(res, toItineraryResponse(itinerary), 201);
  } catch (err) {
    return next(err);
  }
}

async function publish(req, res, next) {
  try {
    const sharedRoute = await itineraryService.publishItinerary(req.user.userId, req.params.id, req.body.title);
    return success(res, toPublishedRouteResponse(sharedRoute), 201);
  } catch (err) {
    return next(err);
  }
}

module.exports = { create, publish, toItineraryResponse };
