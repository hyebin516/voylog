const savedWalkingCourseService = require('../services/saved-walking-course.service');
const { success } = require('../utils/response');

function toSavedCourseResponse(course) {
  return {
    savedCourseId: course.saved_course_id,
    region: course.region,
    routeType: course.route_type,
    transportMode: course.transport_mode,
    totalDistanceM: course.total_distance_m,
    totalDurationSec: course.total_duration_sec,
    routeData: course.route_data,
    createdAt: course.created_at,
  };
}

async function create(req, res, next) {
  try {
    const { region, routeType, transportMode, totalDistanceM, totalDurationSec, routeData } = req.body;
    const course = await savedWalkingCourseService.saveCourse(req.user.userId, {
      region,
      routeType,
      transportMode,
      totalDistanceM,
      totalDurationSec,
      routeData,
    });
    return success(res, toSavedCourseResponse(course), 201);
  } catch (err) {
    return next(err);
  }
}

async function list(req, res, next) {
  try {
    const courses = await savedWalkingCourseService.listCourses(req.user.userId);
    return success(res, { savedCourses: courses.map(toSavedCourseResponse) });
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    await savedWalkingCourseService.deleteCourse(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { create, list, remove };
