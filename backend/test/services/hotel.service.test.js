jest.mock('../../src/repositories/hotel.repository');

const hotelRepository = require('../../src/repositories/hotel.repository');
const hotelService = require('../../src/services/hotel.service');

const USER_ID = 'user-1';
const HOTEL_ID = 'hotel-1';

afterEach(() => jest.clearAllMocks());

describe('getOwnedHotel', () => {
  it('returns the hotel when it belongs to the requesting user', async () => {
    hotelRepository.findById.mockResolvedValue({ hotel_id: HOTEL_ID, user_id: USER_ID });
    const hotel = await hotelService.getOwnedHotel(USER_ID, HOTEL_ID);
    expect(hotel.hotel_id).toBe(HOTEL_ID);
  });

  it('throws 404 HOTEL_NOT_FOUND when the hotel does not exist', async () => {
    hotelRepository.findById.mockResolvedValue(null);
    await expect(hotelService.getOwnedHotel(USER_ID, HOTEL_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'HOTEL_NOT_FOUND',
    });
  });

  it('throws 404 HOTEL_NOT_FOUND when the hotel belongs to another user (never leak existence across users)', async () => {
    hotelRepository.findById.mockResolvedValue({ hotel_id: HOTEL_ID, user_id: 'someone-else' });
    await expect(hotelService.getOwnedHotel(USER_ID, HOTEL_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'HOTEL_NOT_FOUND',
    });
  });
});

describe('updateHotel', () => {
  it('checks ownership before updating', async () => {
    hotelRepository.findById.mockResolvedValue({ hotel_id: HOTEL_ID, user_id: USER_ID });
    hotelRepository.update.mockResolvedValue({ hotel_id: HOTEL_ID, name: 'New name' });

    const result = await hotelService.updateHotel(USER_ID, HOTEL_ID, { name: 'New name' });

    expect(hotelRepository.update).toHaveBeenCalledWith(HOTEL_ID, { name: 'New name' });
    expect(result.name).toBe('New name');
  });

  it('refuses to update a hotel owned by another user', async () => {
    hotelRepository.findById.mockResolvedValue({ hotel_id: HOTEL_ID, user_id: 'someone-else' });

    await expect(hotelService.updateHotel(USER_ID, HOTEL_ID, { name: 'x' })).rejects.toMatchObject({
      statusCode: 404,
    });
    expect(hotelRepository.update).not.toHaveBeenCalled();
  });
});

describe('deleteHotel', () => {
  it('soft-deletes a hotel owned by the requesting user', async () => {
    hotelRepository.findById.mockResolvedValue({ hotel_id: HOTEL_ID, user_id: USER_ID });

    await hotelService.deleteHotel(USER_ID, HOTEL_ID);

    expect(hotelRepository.softDelete).toHaveBeenCalledWith(HOTEL_ID);
  });

  it('refuses to delete a hotel owned by another user', async () => {
    hotelRepository.findById.mockResolvedValue({ hotel_id: HOTEL_ID, user_id: 'someone-else' });

    await expect(hotelService.deleteHotel(USER_ID, HOTEL_ID)).rejects.toMatchObject({ statusCode: 404 });
    expect(hotelRepository.softDelete).not.toHaveBeenCalled();
  });
});
