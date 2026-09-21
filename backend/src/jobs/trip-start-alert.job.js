const { sendDueTripStartAlerts, isWithinSendWindow } = require('../services/trip-start-alert.service');

/**
 * Runs the FR-12 trip-start reminder sweep hourly. Hourly rather than
 * daily so a server that was down at the send hour still gets the day's
 * reminders out; `start_alert_sent_at` keeps each trip to one.
 */

const FIRST_CHECK_DELAY_MS = 60 * 1000;
const CHECK_INTERVAL_MS = 60 * 60 * 1000;

async function checkAndSend(now = new Date()) {
  if (!isWithinSendWindow(now)) return { sent: 0, considered: 0, skipped: 'outside send window' };
  try {
    const result = await sendDueTripStartAlerts(now);
    if (result.considered > 0) {
      console.log(`Trip start reminders: sent ${result.sent} of ${result.considered} due`);
    }
    return result;
  } catch (err) {
    // A failed sweep just means the next hour tries again.
    console.warn(`Trip start reminder sweep failed: ${err.message}`);
    return { sent: 0, considered: 0, skipped: 'error' };
  }
}

function startTripStartAlertSchedule() {
  setTimeout(checkAndSend, FIRST_CHECK_DELAY_MS).unref();
  setInterval(checkAndSend, CHECK_INTERVAL_MS).unref();
}

module.exports = { startTripStartAlertSchedule, checkAndSend };
