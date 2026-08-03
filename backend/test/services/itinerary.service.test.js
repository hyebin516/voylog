jest.mock('../../src/repositories/itinerary.repository');
jest.mock('../../src/repositories/place.repository');
jest.mock('../../src/services/hotel.service');
jest.mock('../../src/services/aiWorkerClient');

const itineraryRepository = require('../../src/repositories/itinerary.repository');
const placeRepository = require('../../src/repositories/place.repository');
const hotelService = require('../../src/services/hotel.service');
const { callAiWorker } = require('../../src/services/aiWorkerClient');
const { createItinerary } = require('../../src/services/itinerary.service');
const AppError = require('../../src/utils/AppError');

const USER_ID = 'user-1';
const HOTEL_A = 'hotel-a';
const HOTEL_B = 'hotel-b';

const geocodedPlace = (id) => ({ place_id: id, name: `Place ${id}`, latitude: 37.5, longitude: 127.0 });
const ungeocodedPlace = (id) => ({ place_id: id, name: `Place ${id}`, latitude: null, longitude: null });

function hotelPayload(id) {
  return { hotel_id: id, name: `Hotel ${id}`, latitude: 37.0, longitude: 127.0, address: 'addr' };
}

beforeEach(() => {
  hotelService.getOwnedHotel.mockImplementation(async (userId, hotelId) => hotelPayload(hotelId));
  callAiWorker.mockResolvedValue({ routeData: {} });
  itineraryRepository.create.mockResolvedValue({ itinerary_id: 'it-1' });
});

afterEach(() => jest.clearAllMocks());

describe('createItinerary route_type derivation', () => {
  it('derives roundTrip when startHotelId === endHotelId, and only looks up the hotel once', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);

    await createItinerary(USER_ID, HOTEL_A, HOTEL_A, ['p1', 'p2']);

    expect(hotelService.getOwnedHotel).toHaveBeenCalledTimes(1);
    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.routeType).toBe('roundTrip');
  });

  it('derives hotelToHotel when startHotelId !== endHotelId, and looks up both hotels', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);

    await createItinerary(USER_ID, HOTEL_A, HOTEL_B, ['p1', 'p2']);

    expect(hotelService.getOwnedHotel).toHaveBeenCalledTimes(2);
    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.routeType).toBe('hotelToHotel');
  });

  it('never trusts a client-controlled routeType — it is always server-derived', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);

    await createItinerary(USER_ID, HOTEL_A, HOTEL_A, ['p1', 'p2']);

    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.routeType).toBe('roundTrip');
    expect(payload).not.toHaveProperty('startHotelId'); // only hotel objects are forwarded, not raw ids
  });
});

describe('createItinerary place validation', () => {
  it('filters out places without coordinates before counting toward the minimum', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), ungeocodedPlace('p2')]);

    await expect(createItinerary(USER_ID, HOTEL_A, HOTEL_A, ['p1', 'p2'])).rejects.toMatchObject({
      statusCode: 400,
      code: 'INVALID_REQUEST',
    });
    expect(callAiWorker).not.toHaveBeenCalled();
  });

  it('proceeds when at least 2 places have valid coordinates, excluding ungeocoded ones from the payload', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2'), ungeocodedPlace('p3')]);

    await createItinerary(USER_ID, HOTEL_A, HOTEL_A, ['p1', 'p2', 'p3']);

    const [, payload] = callAiWorker.mock.calls[0];
    expect(payload.places).toHaveLength(2);
    expect(payload.places.map((p) => p.placeId)).toEqual(['p1', 'p2']);
  });
});

describe('createItinerary persistence', () => {
  it('saves the itinerary using the derived route type via the optimized AI worker result', async () => {
    placeRepository.findByIds.mockResolvedValue([geocodedPlace('p1'), geocodedPlace('p2')]);
    callAiWorker.mockResolvedValue({ totalDistanceM: 1000, totalDurationSec: 600 });

    const result = await createItinerary(USER_ID, HOTEL_A, HOTEL_B, ['p1', 'p2']);

    expect(itineraryRepository.create).toHaveBeenCalledWith(USER_ID, HOTEL_A, HOTEL_B, {
      totalDistanceM: 1000,
      totalDurationSec: 600,
    });
    expect(result.itinerary_id).toBe('it-1');
  });
});
