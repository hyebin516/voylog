const notificationSettingsService = require('../services/notification-settings.service');
const { success } = require('../utils/response');

function toResponse(settings) {
  return {
    tripAlerts: settings.trip_alerts,
    serviceAlerts: settings.service_alerts,
    marketingAlerts: settings.marketing_alerts,
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
    const { tripAlerts, serviceAlerts, marketingAlerts } = req.body;
    const settings = await notificationSettingsService.updateSettings(req.user.userId, {
      tripAlerts,
      serviceAlerts,
      marketingAlerts,
    });
    return success(res, toResponse(settings));
  } catch (err) {
    return next(err);
  }
}

module.exports = { get, update };
