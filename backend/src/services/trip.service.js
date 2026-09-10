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

async function createTrip(userId, name, startDate, endDate) {
  return tripRepository.create(userId, name, startDate, endDate);
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

// No ownership check -- this backs the public "링크 복사" share page
// (GET /trips/:id/share), intentionally reachable by anyone holding the
// link, not just the trip's owner.
async function getTripShareView(tripId) {
  const trip = await tripRepository.findById(tripId);
  if (!trip) {
    throw new AppError(404, 'TRIP_NOT_FOUND', 'Trip not found');
  }
  const days = await itineraryRepository.findAllByTrip(tripId);
  return { ...trip, days };
}

async function deleteTrip(userId, tripId) {
  await getOwnedTrip(userId, tripId);
  await tripRepository.softDelete(tripId);
}

async function updateTripDates(userId, tripId, startDate, endDate) {
  await getOwnedTrip(userId, tripId);
  return tripRepository.updateDates(tripId, startDate, endDate);
}

module.exports = {
  getOwnedTrip,
  createTrip,
  listTrips,
  getTripWithDays,
  getTripShareView,
  deleteTrip,
  updateTripDates,
};
