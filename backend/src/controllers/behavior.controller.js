const behaviorService = require('../services/behavior.service');

async function record(req, res, next) {
  try {
    const { placeId, action, screen, distanceMeters } = req.body;
    await behaviorService.recordBehavior(req.user.userId, { placeId, action, screen, distanceMeters });
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { record };
