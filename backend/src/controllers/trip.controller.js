const tripService = require('../services/trip.service');
const { toItineraryResponse } = require('./itinerary.controller');
const { success } = require('../utils/response');

function toTripResponse(trip) {
  return {
    tripId: trip.trip_id,
    name: trip.name,
    dayCount: trip.day_count,
    createdAt: trip.created_at,
  };
}

function toTripDetailResponse(trip) {
  return {
    tripId: trip.trip_id,
    name: trip.name,
    createdAt: trip.created_at,
    days: trip.days.map(toItineraryResponse),
  };
}

async function create(req, res, next) {
  try {
    const trip = await tripService.createTrip(req.user.userId, req.body.name);
    return success(res, { tripId: trip.trip_id, name: trip.name, createdAt: trip.created_at }, 201);
  } catch (err) {
    return next(err);
  }
}

async function list(req, res, next) {
  try {
    const trips = await tripService.listTrips(req.user.userId);
    return success(res, { trips: trips.map(toTripResponse) });
  } catch (err) {
    return next(err);
  }
}

async function get(req, res, next) {
  try {
    const trip = await tripService.getTripWithDays(req.user.userId, req.params.id);
    return success(res, toTripDetailResponse(trip));
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    await tripService.deleteTrip(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { create, list, get, remove };
