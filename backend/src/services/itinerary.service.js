const itineraryRepository = require('../repositories/itinerary.repository');
const placeRepository = require('../repositories/place.repository');
const hotelService = require('./hotel.service');
const tripService = require('./trip.service');
const { callAiWorker } = require('./aiWorkerClient');
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

module.exports = { createItinerary };
