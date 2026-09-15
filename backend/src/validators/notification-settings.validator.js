const AppError = require('../utils/AppError');

function validateUpdateNotificationSettings(req, res, next) {
  const { newVlogAlerts, routeCompleteAlerts, marketingAlerts, nightSilent } = req.body;
  if (
    typeof newVlogAlerts !== 'boolean' ||
    typeof routeCompleteAlerts !== 'boolean' ||
    typeof marketingAlerts !== 'boolean' ||
    typeof nightSilent !== 'boolean'
  ) {
    return next(
      new AppError(
        400,
        'INVALID_REQUEST',
        'newVlogAlerts, routeCompleteAlerts, marketingAlerts, and nightSilent must all be booleans'
      )
    );
  }
  return next();
}

module.exports = { validateUpdateNotificationSettings };
