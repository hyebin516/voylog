jest.mock('../../src/repositories/trip.repository');
jest.mock('../../src/repositories/itinerary.repository');

const tripRepository = require('../../src/repositories/trip.repository');
const itineraryRepository = require('../../src/repositories/itinerary.repository');
const tripService = require('../../src/services/trip.service');

const USER_ID = 'user-1';
const TRIP_ID = 'trip-1';

afterEach(() => jest.clearAllMocks());

describe('getOwnedTrip', () => {
  it('returns the trip when it belongs to the requesting user', async () => {
    tripRepository.findById.mockResolvedValue({ trip_id: TRIP_ID, user_id: USER_ID });
    const trip = await tripService.getOwnedTrip(USER_ID, TRIP_ID);
    expect(trip.trip_id).toBe(TRIP_ID);
  });

  it('throws 404 TRIP_NOT_FOUND when the trip does not exist', async () => {
    tripRepository.findById.mockResolvedValue(null);
    await expect(tripService.getOwnedTrip(USER_ID, TRIP_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'TRIP_NOT_FOUND',
    });
  });

  it('throws 404 TRIP_NOT_FOUND when the trip belongs to another user', async () => {
    tripRepository.findById.mockResolvedValue({ trip_id: TRIP_ID, user_id: 'someone-else' });
    await expect(tripService.getOwnedTrip(USER_ID, TRIP_ID)).rejects.toMatchObject({ statusCode: 404 });
  });
});

describe('createTrip', () => {
  it('creates a trip for the user with the given name', async () => {
    tripRepository.create.mockResolvedValue({ trip_id: TRIP_ID, name: '제주도 여행' });
    const trip = await tripService.createTrip(USER_ID, '제주도 여행');
    expect(tripRepository.create).toHaveBeenCalledWith(USER_ID, '제주도 여행');
    expect(trip.name).toBe('제주도 여행');
  });
});

describe('listTrips', () => {
  it('attaches a day count to each trip', async () => {
    tripRepository.findAllByUser.mockResolvedValue([
      { trip_id: 't1', name: 'Trip 1' },
      { trip_id: 't2', name: 'Trip 2' },
    ]);
    tripRepository.countDaysByTrip.mockImplementation(async (tripId) => (tripId === 't1' ? 3 : 0));

    const trips = await tripService.listTrips(USER_ID);

    expect(trips).toEqual([
      { trip_id: 't1', name: 'Trip 1', day_count: 3 },
      { trip_id: 't2', name: 'Trip 2', day_count: 0 },
    ]);
  });
});

describe('getTripWithDays', () => {
  it('returns the trip with its days ordered by the repository', async () => {
    tripRepository.findById.mockResolvedValue({ trip_id: TRIP_ID, user_id: USER_ID, name: '제주도 여행' });
    itineraryRepository.findAllByTrip.mockResolvedValue([
      { itinerary_id: 'day-1', day_number: 1 },
      { itinerary_id: 'day-2', day_number: 2 },
    ]);

    const trip = await tripService.getTripWithDays(USER_ID, TRIP_ID);

    expect(trip.days).toHaveLength(2);
    expect(itineraryRepository.findAllByTrip).toHaveBeenCalledWith(TRIP_ID);
  });

  it('throws 404 when the trip is not owned by the user', async () => {
    tripRepository.findById.mockResolvedValue(null);
    await expect(tripService.getTripWithDays(USER_ID, TRIP_ID)).rejects.toMatchObject({ statusCode: 404 });
  });
});

describe('deleteTrip', () => {
  it('soft-deletes the trip after verifying ownership', async () => {
    tripRepository.findById.mockResolvedValue({ trip_id: TRIP_ID, user_id: USER_ID });

    await tripService.deleteTrip(USER_ID, TRIP_ID);

    expect(tripRepository.softDelete).toHaveBeenCalledWith(TRIP_ID);
  });

  it('refuses to delete a trip owned by another user', async () => {
    tripRepository.findById.mockResolvedValue({ trip_id: TRIP_ID, user_id: 'someone-else' });

    await expect(tripService.deleteTrip(USER_ID, TRIP_ID)).rejects.toMatchObject({ statusCode: 404 });
    expect(tripRepository.softDelete).not.toHaveBeenCalled();
  });
});
