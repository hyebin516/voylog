const { validateNearbyRequest } = require('../../src/validators/recommendation.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_BODY = { latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00+09:00' };

describe('validateNearbyRequest', () => {
  it('passes for a valid latitude/longitude/localTime', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: VALID_BODY }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing latitude', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: { longitude: 127.0, localTime: VALID_BODY.localTime } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a latitude out of range', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, latitude: 200 } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a longitude out of range', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, longitude: -200 } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an unparseable localTime', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, localTime: 'not-a-date' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a radiusMeters above the cap', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, radiusMeters: 999999 } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a limit above the cap', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, limit: 999 } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('passes when optional radiusMeters/limit are within bounds', () => {
    const next = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, radiusMeters: 1000, limit: 5 } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });
});
