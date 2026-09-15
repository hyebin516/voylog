const recommendationService = require('../services/recommendation.service');
const { success } = require('../utils/response');

async function nearby(req, res, next) {
  try {
    const { latitude, longitude, localTime, radiusMeters, limit, categoryGroup } = req.body;
    const result = await recommendationService.getNearbyRecommendations({
      userId: req.user ? req.user.userId : null,
      latitude,
      longitude,
      localTime,
      radiusMeters,
      limit,
      categoryGroup,
    });
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

async function walkingCourse(req, res, next) {
  try {
    const { region, localTime, mood, walkDuration, startLatitude, startLongitude, startName, avoidPlaceIds } =
      req.body;
    const result = await recommendationService.getWalkingCourse({
      userId: req.user ? req.user.userId : null,
      region,
      localTime,
      mood,
      walkDuration,
      startLatitude,
      startLongitude,
      startName,
      avoidPlaceIds,
    });
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

async function similarTaste(req, res, next) {
  try {
    const limit = req.query.limit !== undefined ? Number(req.query.limit) : undefined;
    const result = await recommendationService.getSimilarTasteRecommendations({
      userId: req.user.userId,
      limit,
    });
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

module.exports = { nearby, walkingCourse, similarTaste };
