const savedWalkingCourseRepository = require('../repositories/saved-walking-course.repository');
const sharedRouteRepository = require('../repositories/shared-route.repository');
const { buildPublicRouteSnapshot } = require('../utils/route-snapshot');
const { materializeRoutePlaces } = require('./kakao-place.service');
const AppError = require('../utils/AppError');

async function getOwnedCourse(userId, savedCourseId) {
  const course = await savedWalkingCourseRepository.findById(savedCourseId);
  if (!course || course.user_id !== userId) {
    throw new AppError(404, 'SAVED_COURSE_NOT_FOUND', 'Saved walking course not found');
  }
  return course;
}

async function saveCourse(userId, course) {
  // Keeping a course is what makes its Kakao-search places worth a row in
  // `places` -- without one they cannot be bookmarked from the course, and
  // a like on the published version would learn nothing from them.
  const routeData = await materializeRoutePlaces(course.routeData);
  return savedWalkingCourseRepository.create(userId, { ...course, routeData });
}

async function listCourses(userId) {
  return savedWalkingCourseRepository.findAllByUser(userId);
}

async function deleteCourse(userId, savedCourseId) {
  await getOwnedCourse(userId, savedCourseId);
  await savedWalkingCourseRepository.softDelete(savedCourseId);
}

async function publishCourse(userId, savedCourseId, title) {
  const course = await getOwnedCourse(userId, savedCourseId);

  const existing = await sharedRouteRepository.findActiveBySource(userId, 'saved_walking_course', course.saved_course_id);
  if (existing) {
    throw new AppError(409, 'ALREADY_PUBLISHED', 'This course is already published');
  }

  // Courses saved before this ran still hold "kakao:" ids, so publishing
  // resolves them too rather than carrying them into the public feed.
  const snapshot = buildPublicRouteSnapshot(await materializeRoutePlaces(course.route_data));
  return sharedRouteRepository.create(userId, {
    sourceType: 'saved_walking_course',
    sourceId: course.saved_course_id,
    title,
    transportMode: course.transport_mode,
    ...snapshot,
  });
}

module.exports = { saveCourse, listCourses, deleteCourse, getOwnedCourse, publishCourse };
