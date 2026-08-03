const { validateCreateHotel, validateHotelId } = require('../../src/validators/hotel.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_UUID = '5ad1f447-a1e2-46a0-8093-0d007ff3071d';
const VALID_HOTEL = { name: 'Grand Hotel', address: 'Seoul', latitude: 37.5, longitude: 127.0 };

describe('validateCreateHotel', () => {
  it('passes for a fully-populated hotel', () => {
    const next = jest.fn();
    validateCreateHotel(mockReq({ body: VALID_HOTEL }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it.each(['name', 'address'])('rejects a missing %s', (field) => {
    const body = { ...VALID_HOTEL, [field]: undefined };
    const next = jest.fn();
    validateCreateHotel(mockReq({ body }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it.each(['latitude', 'longitude'])('rejects a non-numeric %s (never accepts manual text coordinates)', (field) => {
    const body = { ...VALID_HOTEL, [field]: '37.5' };
    const next = jest.fn();
    validateCreateHotel(mockReq({ body }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateHotelId', () => {
  it('passes for a valid uuid param', () => {
    const next = jest.fn();
    validateHotelId(mockReq({ params: { id: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a non-uuid param', () => {
    const next = jest.fn();
    validateHotelId(mockReq({ params: { id: 'nope' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
