const notificationSettingsRepository = require('../repositories/notification-settings.repository');

const DEFAULTS = { trip_start_alerts: true, route_complete_alerts: true, marketing_alerts: false, night_silent: false };

async function getSettings(userId) {
  const settings = await notificationSettingsRepository.find(userId);
  return settings || { user_id: userId, ...DEFAULTS };
}

async function updateSettings(userId, settings) {
  return notificationSettingsRepository.upsert(userId, settings);
}

module.exports = { getSettings, updateSettings };
