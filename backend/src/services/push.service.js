const fs = require('fs');
const deviceTokenRepository = require('../repositories/device-token.repository');
const notificationSettingsService = require('./notification-settings.service');
const env = require('../config/env');

/**
 * Sends the app's push notifications through Firebase Cloud Messaging
 * (FR-12). Every send is checked against the user's notification settings
 * first -- the settings screen has stored them since before there was
 * anything to send.
 *
 * Without FIREBASE_SERVICE_ACCOUNT_PATH configured this is a no-op that
 * says so once: the rest of the app (video analysis above all) must work
 * exactly the same on a machine with no Firebase project.
 */

// Notifications are quiet between these hours for users who asked for it.
// Korean local time, not the server's: this app's users are in Korea, and
// a server in another zone must not shift their night.
const NIGHT_SILENT_FROM_HOUR = 22;
const NIGHT_SILENT_TO_HOUR = 8;
const APP_TIME_ZONE = 'Asia/Seoul';

// Which settings toggle governs which notification.
const SETTING_BY_KIND = {
  analysisComplete: 'route_complete_alerts',
  tripStart: 'trip_start_alerts',
  marketing: 'marketing_alerts',
};

let messaging = null;
let initialised = false;

function getMessaging() {
  if (initialised) return messaging;
  initialised = true;

  const keyPath = env.firebaseServiceAccountPath;
  if (!keyPath || !fs.existsSync(keyPath)) {
    console.warn('Push notifications are off: no Firebase service account at FIREBASE_SERVICE_ACCOUNT_PATH');
    return null;
  }
  // Required lazily so a machine without the SDK installed still boots.
  const admin = require('firebase-admin');
  const app = admin.apps.length
    ? admin.app()
    : admin.initializeApp({ credential: admin.credential.cert(JSON.parse(fs.readFileSync(keyPath, 'utf8'))) });
  messaging = admin.messaging(app);
  return messaging;
}

function hourInAppZone(now = new Date()) {
  return Number(
    new Intl.DateTimeFormat('en-US', { timeZone: APP_TIME_ZONE, hour: 'numeric', hour12: false }).format(now)
  ) % 24;
}

function isNightSilentNow(now = new Date()) {
  const hour = hourInAppZone(now);
  return hour >= NIGHT_SILENT_FROM_HOUR || hour < NIGHT_SILENT_TO_HOUR;
}

/**
 * @returns {Promise<{sent: number, skipped?: string}>} what happened, so
 * callers can log it. Never throws: a notification failing must not fail
 * the job that produced it.
 */
async function sendToUser(userId, { kind, title, body, data = {}, now = new Date() }) {
  try {
    const settingKey = SETTING_BY_KIND[kind];
    if (!settingKey) throw new Error(`Unknown notification kind: ${kind}`);

    const settings = await notificationSettingsService.getSettings(userId);
    if (!settings[settingKey]) return { sent: 0, skipped: 'turned off' };
    if (settings.night_silent && isNightSilentNow(now)) return { sent: 0, skipped: 'night silent' };

    const client = getMessaging();
    if (!client) return { sent: 0, skipped: 'firebase not configured' };

    const tokens = await deviceTokenRepository.findByUser(userId);
    if (tokens.length === 0) return { sent: 0, skipped: 'no devices' };

    const response = await client.sendEachForMulticast({
      tokens: tokens.map((t) => t.token),
      notification: { title, body },
      // Values must be strings; the app reads these to open the right screen.
      data: Object.fromEntries(Object.entries({ kind, ...data }).map(([k, v]) => [k, String(v)])),
    });

    // A token for an app that was uninstalled stays in the table forever
    // otherwise, and every later send retries it.
    await Promise.all(
      response.responses.map(async (result, index) => {
        const code = result.error?.code;
        if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-argument') {
          await deviceTokenRepository.remove(tokens[index].token);
        }
      })
    );

    return { sent: response.successCount };
  } catch (err) {
    console.warn(`Push notification (${kind}) for user ${userId} failed: ${err.message}`);
    return { sent: 0, skipped: 'error' };
  }
}

module.exports = { sendToUser, isNightSilentNow, NIGHT_SILENT_FROM_HOUR, NIGHT_SILENT_TO_HOUR };
