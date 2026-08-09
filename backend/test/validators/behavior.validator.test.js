const { validateRecordBehavior } = require('../../src/validators/behavior.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_BODY = { placeId: '5ad1f447-a1e2-46a0-8093-0d007ff3071d', action: 'bookmark' };

describe('validateRecordBehavior', () => {
  it('passes for a valid placeId/action', () => {
    const next = jest.fn();
    validateRecordBehavior(mockReq({ body: VALID_BODY }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing placeId', () => {
    const next = jest.fn();
    validateRecordBehavior(mockReq({ body: { action: 'bookmark' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a placeId that is not a UUID', () => {
    const next = jest.fn();
    validateRecordBehavior(mockReq({ body: { ...VALID_BODY, placeId: 'not-a-uuid' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an action outside the fixed weight table', () => {
    const next = jest.fn();
    validateRecordBehavior(mockReq({ body: { ...VALID_BODY, action: 'super_like' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a non-numeric distanceMeters', () => {
    const next = jest.fn();
    validateRecordBehavior(mockReq({ body: { ...VALID_BODY, distanceMeters: 'far' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a negative distanceMeters', () => {
    const next = jest.fn();
    validateRecordBehavior(mockReq({ body: { ...VALID_BODY, distanceMeters: -1 } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a non-string screen', () => {
    const next = jest.fn();
    validateRecordBehavior(mockReq({ body: { ...VALID_BODY, screen: 42 } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('passes with optional screen/distanceMeters provided', () => {
    const next = jest.fn();
    validateRecordBehavior(
      mockReq({ body: { ...VALID_BODY, screen: 'nearby', distanceMeters: 150 } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });
});
