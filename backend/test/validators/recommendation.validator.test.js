const {
  validateNearbyRequest,
  validateWalkingCourseRequest,
  validateSimilarTasteLimit,
} = require('../../src/validators/recommendation.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_BODY = { latitude: 37.5, longitude: 127.0, localTime: '2026-08-10T12:00:00+09:00' };

describe('validateNearbyRequest', () => {
  it('accepts a known categoryGroup and rejects an unknown one', () => {
    const ok = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, categoryGroup: 'cafe' } }), mockRes(), ok);
    expect(ok).toHaveBeenCalledWith();

    const bad = jest.fn();
    validateNearbyRequest(mockReq({ body: { ...VALID_BODY, categoryGroup: '카페' } }), mockRes(), bad);
    expect(bad.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

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

describe('validateWalkingCourseRequest', () => {
  const VALID_COURSE_BODY = { region: '제주', localTime: '2026-08-10T12:00:00+09:00' };

  it('passes for a valid region/localTime', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: VALID_COURSE_BODY }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing region', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { localTime: VALID_COURSE_BODY.localTime } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an empty/whitespace-only region', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { ...VALID_COURSE_BODY, region: '   ' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an unparseable localTime', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { ...VALID_COURSE_BODY, localTime: 'not-a-date' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('passes for a complete start point', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(
      mockReq({ body: { ...VALID_COURSE_BODY, startLatitude: 33.5, startLongitude: 126.5, startName: '제주공항' } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a half-specified start point', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(
      mockReq({ body: { ...VALID_COURSE_BODY, startLatitude: 33.5 } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects out-of-range start coordinates', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(
      mockReq({ body: { ...VALID_COURSE_BODY, startLatitude: 999, startLongitude: 126.5 } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a non-numeric start coordinate', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(
      mockReq({ body: { ...VALID_COURSE_BODY, startLatitude: '33.5', startLongitude: 126.5 } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('passes when mood and walkDuration are omitted', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: VALID_COURSE_BODY }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('passes for a valid mood and walkDuration', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(
      mockReq({ body: { ...VALID_COURSE_BODY, mood: '힙한', walkDuration: '2~3시간' } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects an unrecognized mood', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { ...VALID_COURSE_BODY, mood: '존재하지않는분위기' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an unrecognized walkDuration', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { ...VALID_COURSE_BODY, walkDuration: '하루종일' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateSimilarTasteLimit', () => {
  it('passes when limit is omitted', () => {
    const next = jest.fn();
    validateSimilarTasteLimit(mockReq({ query: {} }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('passes for a limit within bounds', () => {
    const next = jest.fn();
    validateSimilarTasteLimit(mockReq({ query: { limit: '10' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a limit above the cap', () => {
    const next = jest.fn();
    validateSimilarTasteLimit(mockReq({ query: { limit: '999' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a non-numeric limit', () => {
    const next = jest.fn();
    validateSimilarTasteLimit(mockReq({ query: { limit: 'abc' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a zero or negative limit', () => {
    const next = jest.fn();
    validateSimilarTasteLimit(mockReq({ query: { limit: '0' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateWalkingCourseRequest avoidPlaceIds', () => {
  const BODY = { region: '제주', localTime: '2026-08-10T12:00:00+09:00' };

  it('passes for an array of place id strings', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { ...BODY, avoidPlaceIds: ['p1', 'kakao:1'] } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a non-array', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { ...BODY, avoidPlaceIds: 'p1' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects non-string entries', () => {
    const next = jest.fn();
    validateWalkingCourseRequest(mockReq({ body: { ...BODY, avoidPlaceIds: [1, 2] } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an oversized list', () => {
    const next = jest.fn();
    const ids = Array.from({ length: 51 }, (_, i) => `p${i}`);
    validateWalkingCourseRequest(mockReq({ body: { ...BODY, avoidPlaceIds: ids } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
