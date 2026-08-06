const AppError = require('../utils/AppError');

function validateUpdateNotificationSettings(req, res, next) {
  const { tripAlerts, serviceAlerts, marketingAlerts } = req.body;
  if (typeof tripAlerts !== 'boolean' || typeof serviceAlerts !== 'boolean' || typeof marketingAlerts !== 'boolean') {
    return next(
      new AppError(400, 'INVALID_REQUEST', 'tripAlerts, serviceAlerts, and marketingAlerts must all be booleans')
    );
  }
  return next();
}

module.exports = { validateUpdateNotificationSettings };
