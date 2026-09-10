const savedWalkingCourseRepository = require('../repositories/saved-walking-course.repository');
const sharedRouteRepository = require('../repositories/shared-route.repository');
const { buildPublicRouteSnapshot } = require('../utils/route-snapshot');
const AppError = require('../utils/AppError');

async function getOwnedCourse(userId, savedCourseId) {
  const course = await savedWalkingCourseRepository.findById(savedCourseId);
  if (!course || course.user_id !== userId) {
    throw new AppError(404, 'SAVED_COURSE_NOT_FOUND', 'Saved walking course not found');
  }
  return course;
}

async function saveCourse(userId, course) {
  return savedWalkingCourseRepository.create(userId, course);
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

  const snapshot = buildPublicRouteSnapshot(course.route_data);
  return sharedRouteRepository.create(userId, {
    sourceType: 'saved_walking_course',
    sourceId: course.saved_course_id,
    title,
    transportMode: course.transport_mode,
    ...snapshot,
  });
}

module.exports = { saveCourse, listCourses, deleteCourse, getOwnedCourse, publishCourse };
