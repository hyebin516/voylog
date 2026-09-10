const tripService = require('../services/trip.service');
const { toItineraryResponse } = require('./itinerary.controller');
const { success } = require('../utils/response');
const escapeHtml = require('../utils/html-escape');

const TRANSPORT_LABELS = { car: '자동차', walk: '도보', transit: '대중교통' };

function formatDistance(meters) {
  if (meters == null) return null;
  return meters >= 1000 ? `${(meters / 1000).toFixed(1)}km` : `${meters}m`;
}

function formatDuration(seconds) {
  if (seconds == null) return null;
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.round((seconds % 3600) / 60);
  return hours > 0 ? `${hours}시간 ${minutes}분` : `${minutes}분`;
}

// The public share page shows hotel *names* (never address/coordinates) --
// a deliberate, narrower exposure than the fully public shared-route feed
// (see route-snapshot.js), since this link is only ever handed out by the
// trip's owner to specific people they choose, not broadcast to every app
// user.
function renderRoutePointsHtml(routePoints) {
  return [...routePoints]
    .sort((a, b) => a.order - b.order)
    .map((point) => {
      const label = point.type === 'hotel' ? `🏨 ${escapeHtml(point.name)}` : escapeHtml(point.name);
      const legDistance = formatDistance(point.legDistanceM);
      const legDuration = formatDuration(point.legDurationSec);
      const leg = legDistance && legDuration ? `<span class="leg">${legDistance} · ${legDuration}</span>` : '';
      return `<li>${leg}<span class="name">${label}</span></li>`;
    })
    .join('');
}

function renderDayHtml(day) {
  const transportLabel = TRANSPORT_LABELS[day.transportMode] || day.transportMode;
  const totalLabel = [formatDistance(day.totalDistanceM), formatDuration(day.totalDurationSec)]
    .filter(Boolean)
    .join(' · ');
  return `
    <section class="day">
      <h2>${day.dayNumber}일차</h2>
      <p class="meta">${escapeHtml(transportLabel)} 이동${totalLabel ? ` · ${escapeHtml(totalLabel)}` : ''}</p>
      <ol class="route">${renderRoutePointsHtml(day.routeData)}</ol>
    </section>`;
}

function renderTripShareHtml(trip) {
  const dateRange = trip.startDate && trip.endDate ? `${trip.startDate} ~ ${trip.endDate}` : '';
  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(trip.name)} - Voylog 여행 일정</title>
<style>
  body { font-family: -apple-system, 'Malgun Gothic', sans-serif; background: #f7fbfd; color: #1c3f52; margin: 0; padding: 24px 16px 48px; }
  .container { max-width: 480px; margin: 0 auto; }
  h1 { font-size: 20px; margin-bottom: 4px; }
  .date-range { color: #7fa6bc; font-size: 13px; margin-bottom: 24px; }
  .day { background: #fff; border-radius: 18px; padding: 18px; margin-bottom: 16px; box-shadow: 0 4px 14px rgba(58,159,216,.07); }
  .day h2 { font-size: 15px; margin: 0 0 4px; }
  .meta { color: #4a90bb; font-size: 12.5px; margin: 0 0 12px; }
  ol.route { list-style: none; margin: 0; padding: 0; }
  ol.route li { padding: 8px 0; border-top: 1px solid #e6f2f9; display: flex; flex-direction: column; }
  ol.route li:first-child { border-top: none; }
  .name { font-size: 14px; font-weight: 600; }
  .leg { font-size: 11.5px; color: #9db8c9; }
</style>
</head>
<body>
  <div class="container">
    <h1>${escapeHtml(trip.name)}</h1>
    <p class="date-range">${escapeHtml(dateRange)}</p>
    ${trip.days.map(renderDayHtml).join('')}
  </div>
</body>
</html>`;
}

// node-postgres returns `date` columns as JS Date objects holding local
// midnight (e.g. `date.getDate()` is correct, but `date.getUTCDate()` isn't).
// `res.json()` serializes Date objects via `.toISOString()`, which reads the
// UTC fields -- for any positive UTC offset (e.g. KST) that silently rolls
// the date back by one day. A trip's start/end date has no time-of-day or
// timezone component at all, so it must go out as a bare YYYY-MM-DD string
// built from the *local* fields, never as a raw Date/ISO-with-time string.
function toDateOnly(date) {
  if (!date) return null;
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function toTripResponse(trip) {
  return {
    tripId: trip.trip_id,
    name: trip.name,
    dayCount: trip.day_count,
    startDate: toDateOnly(trip.start_date),
    endDate: toDateOnly(trip.end_date),
    createdAt: trip.created_at,
  };
}

function toTripDetailResponse(trip) {
  return {
    tripId: trip.trip_id,
    name: trip.name,
    startDate: toDateOnly(trip.start_date),
    endDate: toDateOnly(trip.end_date),
    createdAt: trip.created_at,
    days: trip.days.map(toItineraryResponse),
  };
}

async function create(req, res, next) {
  try {
    const trip = await tripService.createTrip(req.user.userId, req.body.name, req.body.startDate, req.body.endDate);
    return success(
      res,
      {
        tripId: trip.trip_id,
        name: trip.name,
        startDate: toDateOnly(trip.start_date),
        endDate: toDateOnly(trip.end_date),
        createdAt: trip.created_at,
      },
      201
    );
  } catch (err) {
    return next(err);
  }
}

async function list(req, res, next) {
  try {
    const trips = await tripService.listTrips(req.user.userId);
    return success(res, { trips: trips.map(toTripResponse) });
  } catch (err) {
    return next(err);
  }
}

async function get(req, res, next) {
  try {
    const trip = await tripService.getTripWithDays(req.user.userId, req.params.id);
    return success(res, toTripDetailResponse(trip));
  } catch (err) {
    return next(err);
  }
}

async function share(req, res, next) {
  try {
    const trip = await tripService.getTripShareView(req.params.id);
    res.set('Content-Type', 'text/html; charset=utf-8');
    return res.send(renderTripShareHtml(toTripDetailResponse(trip)));
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    await tripService.deleteTrip(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

async function updateDates(req, res, next) {
  try {
    const trip = await tripService.updateTripDates(req.user.userId, req.params.id, req.body.startDate, req.body.endDate);
    return success(res, {
      tripId: trip.trip_id,
      name: trip.name,
      startDate: toDateOnly(trip.start_date),
      endDate: toDateOnly(trip.end_date),
      createdAt: trip.created_at,
    });
  } catch (err) {
    return next(err);
  }
}

module.exports = { create, list, get, share, remove, updateDates };
