const { validateCreateTrip, validateTripId, validateUpdateTripDates } = require('../../src/validators/trip.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_UUID = '5ad1f447-a1e2-46a0-8093-0d007ff3071d';

describe('validateCreateTrip', () => {
  it('passes for a non-empty name', () => {
    const next = jest.fn();
    validateCreateTrip(mockReq({ body: { name: '제주도 여행' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing name', () => {
    const next = jest.fn();
    validateCreateTrip(mockReq({ body: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a whitespace-only name', () => {
    const next = jest.fn();
    validateCreateTrip(mockReq({ body: { name: '   ' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('passes for a valid ISO start/end date range', () => {
    const next = jest.fn();
    validateCreateTrip(
      mockReq({ body: { name: '제주도 여행', startDate: '2026-09-12', endDate: '2026-09-14' } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a malformed date', () => {
    const next = jest.fn();
    validateCreateTrip(mockReq({ body: { name: '제주도 여행', startDate: '2026/09/12' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects startDate after endDate', () => {
    const next = jest.fn();
    validateCreateTrip(
      mockReq({ body: { name: '제주도 여행', startDate: '2026-09-14', endDate: '2026-09-12' } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateTripId', () => {
  it('passes for a valid uuid param', () => {
    const next = jest.fn();
    validateTripId(mockReq({ params: { id: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a non-uuid param', () => {
    const next = jest.fn();
    validateTripId(mockReq({ params: { id: 'nope' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateUpdateTripDates', () => {
  it('passes for a valid ISO start/end date range', () => {
    const next = jest.fn();
    validateUpdateTripDates(
      mockReq({ body: { startDate: '2026-09-12', endDate: '2026-09-14' } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing startDate or endDate (unlike creation, both are required here)', () => {
    const next = jest.fn();
    validateUpdateTripDates(mockReq({ body: { startDate: '2026-09-12' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a malformed date', () => {
    const next = jest.fn();
    validateUpdateTripDates(
      mockReq({ body: { startDate: '2026/09/12', endDate: '2026-09-14' } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects startDate after endDate', () => {
    const next = jest.fn();
    validateUpdateTripDates(
      mockReq({ body: { startDate: '2026-09-14', endDate: '2026-09-12' } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
