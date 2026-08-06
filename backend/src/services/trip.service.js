const tripRepository = require('../repositories/trip.repository');
const itineraryRepository = require('../repositories/itinerary.repository');
const AppError = require('../utils/AppError');

async function getOwnedTrip(userId, tripId) {
  const trip = await tripRepository.findById(tripId);
  if (!trip || trip.user_id !== userId) {
    throw new AppError(404, 'TRIP_NOT_FOUND', 'Trip not found');
  }
  return trip;
}

async function createTrip(userId, name) {
  return tripRepository.create(userId, name);
}

async function listTrips(userId) {
  const trips = await tripRepository.findAllByUser(userId);
  return Promise.all(
    trips.map(async (trip) => ({
      ...trip,
      day_count: await tripRepository.countDaysByTrip(trip.trip_id),
    }))
  );
}

async function getTripWithDays(userId, tripId) {
  const trip = await getOwnedTrip(userId, tripId);
  const days = await itineraryRepository.findAllByTrip(tripId);
  return { ...trip, days };
}

async function deleteTrip(userId, tripId) {
  await getOwnedTrip(userId, tripId);
  await tripRepository.softDelete(tripId);
}

module.exports = { getOwnedTrip, createTrip, listTrips, getTripWithDays, deleteTrip };
