const sharedRouteService = require('../services/shared-route.service');
const { success } = require('../utils/response');

const DEFAULT_FEED_LIMIT = 20;
const MAX_FEED_LIMIT = 50;

function toSharedRouteResponse(row) {
  return {
    sharedRouteId: row.shared_route_id,
    title: row.title,
    authorNickname: row.author_nickname,
    transportMode: row.transport_mode,
    placeCount: row.place_count,
    totalDistanceM: row.total_distance_m,
    totalDurationSec: row.total_duration_sec,
    routeData: row.route_data,
    likeCount: row.like_count,
    likedByMe: row.liked_by_me,
    isOwner: row.is_owner,
    matchPercent: row.match_percent,
    createdAt: row.created_at,
  };
}

// Used by the saved-walking-course/itinerary publish endpoints too (they
// create the same shared_routes row but have no feed-join fields to show).
function toPublishedRouteResponse(route) {
  return {
    sharedRouteId: route.shared_route_id,
    title: route.title,
    transportMode: route.transport_mode,
    placeCount: route.place_count,
    totalDistanceM: route.total_distance_m,
    totalDurationSec: route.total_duration_sec,
    routeData: route.route_data,
    createdAt: route.created_at,
  };
}

async function feed(req, res, next) {
  try {
    const parsedLimit = parseInt(req.query.limit, 10);
    const limit = Math.min(Number.isNaN(parsedLimit) ? DEFAULT_FEED_LIMIT : parsedLimit, MAX_FEED_LIMIT);
    const viewerUserId = req.user ? req.user.userId : null;
    const rows = await sharedRouteService.getSharedRouteFeed({ viewerUserId, limit });
    return success(res, { routes: rows.map(toSharedRouteResponse) });
  } catch (err) {
    return next(err);
  }
}

async function like(req, res, next) {
  try {
    await sharedRouteService.like(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

async function unlike(req, res, next) {
  try {
    await sharedRouteService.unlike(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

async function update(req, res, next) {
  try {
    const route = await sharedRouteService.updateTitle(req.user.userId, req.params.id, req.body.title);
    return success(res, toPublishedRouteResponse(route));
  } catch (err) {
    return next(err);
  }
}

async function unpublish(req, res, next) {
  try {
    await sharedRouteService.unpublish(req.user.userId, req.params.id);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { feed, like, unlike, update, unpublish, toPublishedRouteResponse };
