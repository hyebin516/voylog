const recommendationService = require('../services/recommendation.service');
const { success } = require('../utils/response');

async function nearby(req, res, next) {
  try {
    const { latitude, longitude, localTime, radiusMeters, limit } = req.body;
    const result = await recommendationService.getNearbyRecommendations({
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

module.exports = { nearby };
