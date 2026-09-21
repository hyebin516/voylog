const tripRepository = require('../repositories/trip.repository');
const pushService = require('./push.service');

/**
 * FR-12 "여행 시작 알림": reminds a user the day before a trip they planned
 * starts. Everything it needs is already stored -- a trip's start date --
 * so this is a daily sweep, not an event.
 */

// Korean local time, like the night-silent window in push.service: the
// "day before" a Korean trip must not shift with the server's zone.
const APP_TIME_ZONE = 'Asia/Seoul';

// The reminder goes out in the morning, and any time up to evening if the
// server was down at that hour. Deliberately inside the night-silent
// window's daytime, so a user who silenced nights still gets it today
// instead of having it marked sent and dropped.
const SEND_FROM_HOUR = 10;
const SEND_TO_HOUR = 21;

function appZoneParts(now) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: APP_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hour12: false,
  }).formatToParts(now);
  const get = (type) => parts.find((p) => p.type === type).value;
  return { date: `${get('year')}-${get('month')}-${get('day')}`, hour: Number(get('hour')) % 24 };
}

/** The calendar day after today in the app's time zone, as YYYY-MM-DD. */
function tomorrowInAppZone(now = new Date()) {
  const [year, month, day] = appZoneParts(now).date.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + 1)).toISOString().slice(0, 10);
}

function isWithinSendWindow(now = new Date()) {
  const { hour } = appZoneParts(now);
  return hour >= SEND_FROM_HOUR && hour < SEND_TO_HOUR;
}

/**
 * @returns {Promise<{sent: number, considered: number}>} for the caller's log.
 */
async function sendDueTripStartAlerts(now = new Date()) {
  const trips = await tripRepository.findStartingOnWithoutAlert(tomorrowInAppZone(now));
  let sent = 0;

  for (const trip of trips) {
    // eslint-disable-next-line no-await-in-loop
    const result = await pushService.sendToUser(trip.user_id, {
      kind: 'tripStart',
      title: '내일 여행이 시작돼요',
      body: `"${trip.name}" 여행이 내일 시작돼요. 준비물은 다 챙기셨나요?`,
      data: { tripId: trip.trip_id },
      now,
    });

    // A reminder the user turned off, or has no device for, is done with.
    // One that couldn't be attempted at all (no Firebase configured, or an
    // error) is left unmarked so tomorrow's run still has a chance.
    const unattempted = result.skipped === 'firebase not configured' || result.skipped === 'error';
    if (!unattempted) {
      // eslint-disable-next-line no-await-in-loop
      await tripRepository.markStartAlertSent(trip.trip_id);
      if (result.sent > 0) sent += 1;
    }
  }

  return { sent, considered: trips.length };
}

module.exports = { sendDueTripStartAlerts, tomorrowInAppZone, isWithinSendWindow, SEND_FROM_HOUR, SEND_TO_HOUR };
