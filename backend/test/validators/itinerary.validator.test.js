const { validateCreateItinerary } = require('../../src/validators/itinerary.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const HOTEL_A = '5ad1f447-a1e2-46a0-8093-0d007ff3071d';
const HOTEL_B = '9cc63cdb-0eb1-411a-ae65-55946f3352ae';
const PLACE_1 = '11111111-1111-1111-1111-111111111111';
const PLACE_2 = '22222222-2222-2222-2222-222222222222';

describe('validateCreateItinerary', () => {
  it('passes for distinct start/end hotels and 2 places', () => {
    const req = mockReq({ body: { startHotelId: HOTEL_A, endHotelId: HOTEL_B, placeIds: [PLACE_1, PLACE_2] } });
    const next = jest.fn();
    validateCreateItinerary(req, mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('maps legacy hotelId to both startHotelId and endHotelId (round trip backward-compat)', () => {
    const req = mockReq({ body: { hotelId: HOTEL_A, placeIds: [PLACE_1, PLACE_2] } });
    const next = jest.fn();
    validateCreateItinerary(req, mockRes(), next);
    expect(next).toHaveBeenCalledWith();
    expect(req.body.startHotelId).toBe(HOTEL_A);
    expect(req.body.endHotelId).toBe(HOTEL_A);
  });

  it('rejects when neither hotelId nor startHotelId/endHotelId are present', () => {
    const req = mockReq({ body: { placeIds: [PLACE_1, PLACE_2] } });
    const next = jest.fn();
    validateCreateItinerary(req, mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects fewer than 2 places', () => {
    const req = mockReq({ body: { startHotelId: HOTEL_A, endHotelId: HOTEL_A, placeIds: [PLACE_1] } });
    const next = jest.fn();
    validateCreateItinerary(req, mockRes(), next);
    const err = next.mock.calls[0][0];
    expect(err).toBeInstanceOf(AppError);
    expect(err.code).toBe('INVALID_REQUEST');
  });

  it('rejects more than 10 places', () => {
    const placeIds = Array.from({ length: 11 }, (_, i) => PLACE_1.replace(/1$/, String(i % 10)));
    const req = mockReq({ body: { startHotelId: HOTEL_A, endHotelId: HOTEL_A, placeIds } });
    const next = jest.fn();
    validateCreateItinerary(req, mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a non-uuid place id', () => {
    const req = mockReq({ body: { startHotelId: HOTEL_A, endHotelId: HOTEL_A, placeIds: [PLACE_1, 'not-a-uuid'] } });
    const next = jest.fn();
    validateCreateItinerary(req, mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
