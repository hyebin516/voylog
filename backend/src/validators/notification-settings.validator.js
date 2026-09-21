const AppError = require('../utils/AppError');

function validateUpdateNotificationSettings(req, res, next) {
  const { tripStartAlerts, routeCompleteAlerts, marketingAlerts, nightSilent } = req.body;
  if (
    typeof tripStartAlerts !== 'boolean' ||
    typeof routeCompleteAlerts !== 'boolean' ||
    typeof marketingAlerts !== 'boolean' ||
    typeof nightSilent !== 'boolean'
  ) {
    return next(
      new AppError(
        400,
        'INVALID_REQUEST',
        'tripStartAlerts, routeCompleteAlerts, marketingAlerts, and nightSilent must all be booleans'
      )
    );
  }
  return next();
}

module.exports = { validateUpdateNotificationSettings };
