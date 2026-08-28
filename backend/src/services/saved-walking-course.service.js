const savedWalkingCourseRepository = require('../repositories/saved-walking-course.repository');
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

module.exports = { saveCourse, listCourses, deleteCourse, getOwnedCourse };
