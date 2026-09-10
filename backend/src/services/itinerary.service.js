const itineraryRepository = require('../repositories/itinerary.repository');
const placeRepository = require('../repositories/place.repository');
const sharedRouteRepository = require('../repositories/shared-route.repository');
const hotelService = require('./hotel.service');
const tripService = require('./trip.service');
const { callAiWorker } = require('./aiWorkerClient');
const { buildPublicRouteSnapshot } = require('../utils/route-snapshot');
const AppError = require('../utils/AppError');

function toHotelPayload(hotel) {
  return {
    hotelId: hotel.hotel_id,
    name: hotel.name,
    latitude: hotel.latitude,
    longitude: hotel.longitude,
    address: hotel.address,
  };
}

async function createItinerary(userId, tripId, dayNumber, startHotelId, endHotelId, placeIds, transportMode = 'car') {
  await tripService.getOwnedTrip(userId, tripId);

  const existingDay = await itineraryRepository.findByTripAndDay(tripId, dayNumber);
  if (existingDay) {
    throw new AppError(409, 'DAY_EXISTS', `Day ${dayNumber} already exists for this trip`);
  }

  const startHotel = await hotelService.getOwnedHotel(userId, startHotelId);
  const endHotel =
    endHotelId === startHotelId ? startHotel : await hotelService.getOwnedHotel(userId, endHotelId);

  // routeType is derived server-side, never trusted from client input.
  const routeType = startHotelId === endHotelId ? 'roundTrip' : 'hotelToHotel';

  const places = await placeRepository.findByIds(placeIds);
  const geocodedPlaces = places.filter((p) => p.latitude != null && p.longitude != null);

  if (geocodedPlaces.length < 2) {
    throw new AppError(400, 'INVALID_REQUEST', 'At least 2 places with valid coordinates are required');
  }

  const optimizedResult = await callAiWorker(
    '/optimize-route',
    {
      startHotel: toHotelPayload(startHotel),
      endHotel: toHotelPayload(endHotel),
      places: geocodedPlaces.map((p) => ({
        placeId: p.place_id,
        name: p.name,
        latitude: p.latitude,
        longitude: p.longitude,
      })),
      routeType,
      optimizationPriority: 'duration',
      transportMode,
    },
    15000
  );

  return itineraryRepository.create(userId, tripId, dayNumber, startHotelId, endHotelId, optimizedResult);
}

async function getOwnedItinerary(userId, itineraryId) {
  const itinerary = await itineraryRepository.findById(itineraryId);
  if (!itinerary || itinerary.user_id !== userId) {
    throw new AppError(404, 'ITINERARY_NOT_FOUND', 'Itinerary not found');
  }
  return itinerary;
}

async function publishItinerary(userId, itineraryId, title) {
  const itinerary = await getOwnedItinerary(userId, itineraryId);

  const existing = await sharedRouteRepository.findActiveBySource(userId, 'itinerary', itinerary.itinerary_id);
  if (existing) {
    throw new AppError(409, 'ALREADY_PUBLISHED', 'This itinerary is already published');
  }

  const snapshot = buildPublicRouteSnapshot(itinerary.route_data);
  return sharedRouteRepository.create(userId, {
    sourceType: 'itinerary',
    sourceId: itinerary.itinerary_id,
    title,
    transportMode: itinerary.transport_mode,
    ...snapshot,
  });
}

module.exports = { createItinerary, getOwnedItinerary, publishItinerary };
