jest.mock('../../src/repositories/saved-walking-course.repository');
jest.mock('../../src/repositories/shared-route.repository');

const savedWalkingCourseRepository = require('../../src/repositories/saved-walking-course.repository');
const sharedRouteRepository = require('../../src/repositories/shared-route.repository');
const savedWalkingCourseService = require('../../src/services/saved-walking-course.service');

const USER_ID = 'user-1';
const COURSE_ID = 'course-1';

const ROUTE_DATA = [
  { order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '제주', latitude: 33.5, longitude: 126.5 },
  { order: 1, type: 'place', hotelId: null, placeId: 'p1', name: '흑돼지집', latitude: 33.51, longitude: 126.51 },
];

afterEach(() => jest.clearAllMocks());

describe('getOwnedCourse', () => {
  it('returns the course when it belongs to the requesting user', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue({ saved_course_id: COURSE_ID, user_id: USER_ID });

    const course = await savedWalkingCourseService.getOwnedCourse(USER_ID, COURSE_ID);

    expect(course.saved_course_id).toBe(COURSE_ID);
  });

  it('throws 404 SAVED_COURSE_NOT_FOUND when the course does not exist', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue(null);

    await expect(savedWalkingCourseService.getOwnedCourse(USER_ID, COURSE_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'SAVED_COURSE_NOT_FOUND',
    });
  });

  it('throws 404 SAVED_COURSE_NOT_FOUND when the course belongs to another user', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue({ saved_course_id: COURSE_ID, user_id: 'someone-else' });

    await expect(savedWalkingCourseService.getOwnedCourse(USER_ID, COURSE_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'SAVED_COURSE_NOT_FOUND',
    });
  });
});

describe('saveCourse', () => {
  it('creates a course under the requesting user', async () => {
    const input = {
      region: '제주',
      routeType: 'roundTrip',
      transportMode: 'walk',
      totalDistanceM: 2119,
      totalDurationSec: 1897,
      routeData: ROUTE_DATA,
    };
    savedWalkingCourseRepository.create.mockResolvedValue({ saved_course_id: COURSE_ID, ...input });

    const result = await savedWalkingCourseService.saveCourse(USER_ID, input);

    expect(savedWalkingCourseRepository.create).toHaveBeenCalledWith(USER_ID, input);
    expect(result.saved_course_id).toBe(COURSE_ID);
  });
});

describe('listCourses', () => {
  it('lists the requesting user\'s saved courses', async () => {
    savedWalkingCourseRepository.findAllByUser.mockResolvedValue([{ saved_course_id: COURSE_ID }]);

    const result = await savedWalkingCourseService.listCourses(USER_ID);

    expect(savedWalkingCourseRepository.findAllByUser).toHaveBeenCalledWith(USER_ID);
    expect(result).toHaveLength(1);
  });
});

describe('deleteCourse', () => {
  it('soft-deletes a course owned by the requesting user', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue({ saved_course_id: COURSE_ID, user_id: USER_ID });

    await savedWalkingCourseService.deleteCourse(USER_ID, COURSE_ID);

    expect(savedWalkingCourseRepository.softDelete).toHaveBeenCalledWith(COURSE_ID);
  });

  it('refuses to delete a course owned by another user', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue({ saved_course_id: COURSE_ID, user_id: 'someone-else' });

    await expect(savedWalkingCourseService.deleteCourse(USER_ID, COURSE_ID)).rejects.toMatchObject({ statusCode: 404 });
    expect(savedWalkingCourseRepository.softDelete).not.toHaveBeenCalled();
  });
});

describe('publishCourse', () => {
  it('builds a public snapshot (hotel point stripped) and creates a shared route', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue({
      saved_course_id: COURSE_ID,
      user_id: USER_ID,
      transport_mode: 'walk',
      route_data: ROUTE_DATA,
    });
    sharedRouteRepository.findActiveBySource.mockResolvedValue(null);
    sharedRouteRepository.create.mockResolvedValue({ shared_route_id: 'shared-1' });

    const result = await savedWalkingCourseService.publishCourse(USER_ID, COURSE_ID, '제주 서쪽 카페 코스');

    expect(sharedRouteRepository.create).toHaveBeenCalledWith(USER_ID, {
      sourceType: 'saved_walking_course',
      sourceId: COURSE_ID,
      title: '제주 서쪽 카페 코스',
      transportMode: 'walk',
      routeData: [
        {
          order: 0,
          type: 'place',
          placeId: 'p1',
          name: '흑돼지집',
          latitude: 33.51,
          longitude: 126.51,
          legDistanceM: null,
          legDurationSec: null,
        },
      ],
      totalDistanceM: null,
      totalDurationSec: null,
      placeCount: 1,
    });
    expect(result.shared_route_id).toBe('shared-1');
  });

  it('refuses to publish a course owned by another user', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue({ saved_course_id: COURSE_ID, user_id: 'someone-else' });

    await expect(savedWalkingCourseService.publishCourse(USER_ID, COURSE_ID, 'title')).rejects.toMatchObject({
      statusCode: 404,
    });
    expect(sharedRouteRepository.create).not.toHaveBeenCalled();
  });

  it('refuses to publish the same course twice (409 ALREADY_PUBLISHED)', async () => {
    savedWalkingCourseRepository.findById.mockResolvedValue({
      saved_course_id: COURSE_ID,
      user_id: USER_ID,
      transport_mode: 'walk',
      route_data: ROUTE_DATA,
    });
    sharedRouteRepository.findActiveBySource.mockResolvedValue({ shared_route_id: 'already-shared' });

    await expect(savedWalkingCourseService.publishCourse(USER_ID, COURSE_ID, 'title')).rejects.toMatchObject({
      statusCode: 409,
      code: 'ALREADY_PUBLISHED',
    });
    expect(sharedRouteRepository.create).not.toHaveBeenCalled();
  });
});
