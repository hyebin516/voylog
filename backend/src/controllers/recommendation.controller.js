const recommendationService = require('../services/recommendation.service');
const { success } = require('../utils/response');

async function nearby(req, res, next) {
  try {
    const { latitude, longitude, localTime, radiusMeters, limit } = req.body;
    const result = await recommendationService.getNearbyRecommendations({
      userId: req.user ? req.user.userId : null,
      latitude,
      longitude,
      localTime,
      radiusMeters,
      limit,
    });
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

async function walkingCourse(req, res, next) {
  try {
    const { region, localTime } = req.body;
    const result = await recommendationService.getWalkingCourse({
      userId: req.user ? req.user.userId : null,
      region,
      localTime,
    });
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

module.exports = { nearby, walkingCourse };
