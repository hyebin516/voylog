const { validateCreateSavedCourse, validateSavedCourseId } = require('../../src/validators/saved-walking-course.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_UUID = '5ad1f447-a1e2-46a0-8093-0d007ff3071d';
const VALID_ROUTE_DATA = [
  { order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주', latitude: 33.5, longitude: 126.5 },
  { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '흑돼지집', latitude: 33.51, longitude: 126.51 },
];
const VALID_BODY = {
  region: '제주',
  routeType: 'roundTrip',
  transportMode: 'walk',
  totalDistanceM: 2119,
  totalDurationSec: 1897,
  routeData: VALID_ROUTE_DATA,
};

describe('validateCreateSavedCourse', () => {
  it('passes for a fully-populated course', () => {
    const next = jest.fn();
    validateCreateSavedCourse(mockReq({ body: VALID_BODY }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('passes a bookmark-folder route: place to place, walked and by bus', () => {
    const next = jest.fn();
    const body = {
      ...VALID_BODY,
      region: '부산 코스',
      routeType: 'placeToPlace',
      transportMode: 'mixed',
      routeData: [
        { order: 0, type: 'place', placeId: 'p1', name: 'A', latitude: 35.1, longitude: 129.0 },
        { order: 1, type: 'place', placeId: 'p2', name: 'B', latitude: 35.2, longitude: 129.1, legTransportMode: 'transit', legGuidance: '1003번 · A → B' },
      ],
    };
    validateCreateSavedCourse(mockReq({ body }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing region', () => {
    const next = jest.fn();
    validateCreateSavedCourse(mockReq({ body: { ...VALID_BODY, region: undefined } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an empty/whitespace-only region', () => {
    const next = jest.fn();
    validateCreateSavedCourse(mockReq({ body: { ...VALID_BODY, region: '   ' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an invalid routeType', () => {
    const next = jest.fn();
    validateCreateSavedCourse(mockReq({ body: { ...VALID_BODY, routeType: 'zigzag' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an invalid transportMode', () => {
    const next = jest.fn();
    validateCreateSavedCourse(mockReq({ body: { ...VALID_BODY, transportMode: 'bike' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a non-numeric totalDistanceM', () => {
    const next = jest.fn();
    validateCreateSavedCourse(mockReq({ body: { ...VALID_BODY, totalDistanceM: '2119' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('allows a null totalDistanceM/totalDurationSec', () => {
    const next = jest.fn();
    validateCreateSavedCourse(
      mockReq({ body: { ...VALID_BODY, totalDistanceM: null, totalDurationSec: null } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects an empty routeData array', () => {
    const next = jest.fn();
    validateCreateSavedCourse(mockReq({ body: { ...VALID_BODY, routeData: [] } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a routeData point missing a required field', () => {
    const next = jest.fn();
    const badRouteData = [{ order: 0, type: 'hotel' }]; // missing name
    validateCreateSavedCourse(mockReq({ body: { ...VALID_BODY, routeData: badRouteData } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateSavedCourseId', () => {
  it('passes for a valid uuid param', () => {
    const next = jest.fn();
    validateSavedCourseId(mockReq({ params: { id: VALID_UUID } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a non-uuid param', () => {
    const next = jest.fn();
    validateSavedCourseId(mockReq({ params: { id: 'nope' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
