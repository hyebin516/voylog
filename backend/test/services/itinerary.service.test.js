jest.mock('../../src/repositories/itinerary.repository');
jest.mock('../../src/repositories/place.repository');
jest.mock('../../src/services/hotel.service');
jest.mock('../../src/services/trip.service');
jest.mock('../../src/services/aiWorkerClient');

const itineraryRepository = require('../../src/repositories/itinerary.repository');
const placeRepository = require('../../src/repositories/place.repository');
const hotelService = require('../../src/services/hotel.service');
const tripService = require('../../src/services/trip.service');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { createItinerary } = require('../../src/services/itinerary.service');
const AppError = require('../../src/utils/AppError');

const USER_ID = 'user-1';
const TRIP_ID = 'trip-1';
const HOTEL_A = 'hotel-a';
const HOTEL_B = 'hotel-b';

const geocodedPlace = (id) => ({ place_id: id, name: `Place ${id}`, latitude: 37.5, longitude: 127.0 });
const ungeocodedPlace = (id) => ({ place_id: id, name: `Place ${id}`, latitude: null, longitude: null });

function hotelPayload(id) {
  return { hotel_id: id, name: `Hotel ${id}`, latitude: 37.0, longitude: 127.0, address: 'addr' };
}

beforeEach(() => {
  tripService.getOwnedTrip.mockResolvedValue({ trip_id: TRIP_ID, user_id: USER_ID });
  hotelService.getOwnedHotel.mockImplementation(async (userId, hotelId) => hotelPayload(hotelId));
  itineraryRepository.findByTripAndDay.mockResolvedValue(null);
  callAiWorker.mockResolvedValue({ routeData: {} });
  itineraryRepository.create.mockResolvedValue({ itinerary_id: 'it-1' });
});

afterEach(() => jest.clearAllMocks());

function create(startHotelId, endHotelId, placeIds, dayNumber = 1) {
  return createItinerary(USER_ID, TRIP_ID, dayNumber, startHotelId, endHotelId, placeIds);
}

describe('createItinerary trip/day ownership', () => {
  it('verifies the trip belongs to the requesting user before doing anything else', async () => {
    tripService.getOwnedTrip.mockRejectedValue(new AppError(404, 'TRIP_NOT_FOUND', 'Trip not found'));

    await expect(create(HOTEL_A, HOTEL_A, ['p1', 'p2'])).rejects.toMatchObject({ statusCode: 404, code: 'TRIP_NOT_FOUND' });
    expect(hotelService.getOwnedHotel).not.toHaveBeenCalled();
  });

  it('rejects creating a day that already exists for the trip', async () => {
    itineraryRepository.findByTripAndDay.mockResolvedValue({ itinerary_id: 'existing-day' });

    await expect(create(HOTEL_A, HOTEL_A, ['p1', 'p2'], 1)).rejects.toMatchObject({
      statusCode: 409,
      code: 'DAY_EXISTS',
    });
    expect(hotelService.getOwnedHotel).not.toHaveBeenCalled();
  });

  it('allows different days of the same trip to have different hotel pairs', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);

    await create(HOTEL_A, HOTEL_B, ['p1', 'p2'], 1);
    await create(HOTEL_B, HOTEL_B, ['p1', 'p2'], 2);

    expect(itineraryRepository.findByTripAndDay).toHaveBeenNthCalledWith(1, TRIP_ID, 1);
    expect(itineraryRepository.findByTripAndDay).toHaveBeenNthCalledWith(2, TRIP_ID, 2);
  });
});

describe('createItinerary route_type derivation', () => {
  it('derives roundTrip when startHotelId === endHotelId, and only looks up the hotel once', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);

    await create(HOTEL_A, HOTEL_A, ['p1', 'p2']);

    expect(hotelService.getOwnedHotel).toHaveBeenCalledTimes(1);
    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.routeType).toBe('roundTrip');
  });

  it('derives hotelToHotel when startHotelId !== endHotelId, and looks up both hotels', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);

    await create(HOTEL_A, HOTEL_B, ['p1', 'p2']);

    expect(hotelService.getOwnedHotel).toHaveBeenCalledTimes(2);
    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.routeType).toBe('hotelToHotel');
  });

  it('never trusts a client-controlled routeType — it is always server-derived', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);

    await create(HOTEL_A, HOTEL_A, ['p1', 'p2']);

    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.routeType).toBe('roundTrip');
    expect(payload).not.toHaveProperty('startHotelId'); // only hotel objects are forwarded, not raw ids
  });
});

describe('createItinerary place validation', () => {
  it('filters out places without coordinates before counting toward the minimum', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), ungeocodedPlace('p2')]);

    await expect(create(HOTEL_A, HOTEL_A, ['p1', 'p2'])).rejects.toMatchObject({
      statusCode: 400,
      code: 'INVALID_REQUEST',
    });
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('proceeds when at least 2 places have valid coordinates, excluding ungeocoded ones from the payload', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2'), ungeocodedPlace('p3')]);

    await create(HOTEL_A, HOTEL_A, ['p1', 'p2', 'p3']);

    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.places).toHaveLength(2);
    expect(payload.places.map((p) => p.placeId)).toEqual(['p1', 'p2']);
  });
});

describe('createItinerary persistence', () => {
  it('saves the itinerary under the given trip/day using the optimized AI worker result', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);
    callAiWorker.mockResolvedValue({ totalDistanceM: 1000, totalDurationSec: 600 });

    const result = await create(HOTEL_A, HOTEL_B, ['p1', 'p2'], 2);

    expect(itineraryRepository.create).toHaveBeenCalledWith(USER_ID, TRIP_ID, 2, HOTEL_A, HOTEL_B, {
      totalDistanceM: 1000,
      totalDurationSec: 600,
    });
    expect(result.itinerary_id).toBe('it-1');
  });
});
