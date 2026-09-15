const notificationSettingsService = require('../services/notification-settings.service');
const { success } = require('../utils/response');

function toResponse(settings) {
  return {
    newVlogAlerts: settings.new_vlog_alerts,
    routeCompleteAlerts: settings.route_complete_alerts,
    marketingAlerts: settings.marketing_alerts,
    nightSilent: settings.night_silent,
  };
}

async function get(req, res, next) {
  try {
    const settings = await notificationSettingsService.getSettings(req.user.userId);
    return success(res, toResponse(settings));
  } catch (err) {
    return next(err);
  }
}

async function update(req, res, next) {
  try {
    const { newVlogAlerts, routeCompleteAlerts, marketingAlerts, nightSilent } = req.body;
    const settings = await notificationSettingsService.updateSettings(req.user.userId, {
      newVlogAlerts,
      routeCompleteAlerts,
      marketingAlerts,
      nightSilent,
    });
    return success(res, toResponse(settings));
  } catch (err) {
    return next(err);
  }
}

module.exports = { get, update };
