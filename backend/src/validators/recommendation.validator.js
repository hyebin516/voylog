const AppError = require('../utils/AppError');

// A course has at most 10 stops; this leaves room without inviting abuse.
const MAX_AVOID_PLACE_IDS = 50;

const MAX_RADIUS_M = 5000;
const MAX_LIMIT = 20;

const VALID_NEARBY_CATEGORY_GROUPS = ['restaurant', 'cafe', 'play'];

function validateNearbyRequest(req, res, next) {
  const { latitude, longitude, localTime, radiusMeters, limit, categoryGroup } = req.body;

  if (typeof latitude !== 'number' || latitude < -90 || latitude > 90) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid latitude is required'));
  }
  if (typeof longitude !== 'number' || longitude < -180 || longitude > 180) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid longitude is required'));
  }
  if (typeof localTime !== 'string' || Number.isNaN(Date.parse(localTime))) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid ISO 8601 localTime is required'));
  }
  if (radiusMeters !== undefined && (typeof radiusMeters !== 'number' || radiusMeters <= 0 || radiusMeters > MAX_RADIUS_M)) {
    return next(new AppError(400, 'INVALID_REQUEST', `radiusMeters must be between 1 and ${MAX_RADIUS_M}`));
  }
  if (limit !== undefined && (typeof limit !== 'number' || limit <= 0 || limit > MAX_LIMIT)) {
    return next(new AppError(400, 'INVALID_REQUEST', `limit must be between 1 and ${MAX_LIMIT}`));
  }
  if (categoryGroup !== undefined && !VALID_NEARBY_CATEGORY_GROUPS.includes(categoryGroup)) {
    return next(
      new AppError(400, 'INVALID_REQUEST', `categoryGroup must be one of ${VALID_NEARBY_CATEGORY_GROUPS.join(', ')}`)
    );
  }
  return next();
}

const VALID_WALKING_COURSE_MOODS = ['조용한', '활기찬', '감성적인', '힙한', '전통적인', '로컬스러운'];
const VALID_WALKING_COURSE_DURATIONS = ['1시간 이내', '2~3시간', '반나절'];

function validateWalkingCourseRequest(req, res, next) {
  const { region, localTime, mood, walkDuration, startLatitude, startLongitude, startName, avoidPlaceIds } = req.body;

  if (typeof region !== 'string' || region.trim().length === 0) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty region is required'));
  }
  if (typeof localTime !== 'string' || Number.isNaN(Date.parse(localTime))) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid ISO 8601 localTime is required'));
  }
  if (mood !== undefined && !VALID_WALKING_COURSE_MOODS.includes(mood)) {
    return next(new AppError(400, 'INVALID_REQUEST', `mood must be one of: ${VALID_WALKING_COURSE_MOODS.join(', ')}`));
  }
  if (walkDuration !== undefined && !VALID_WALKING_COURSE_DURATIONS.includes(walkDuration)) {
    return next(
      new AppError(400, 'INVALID_REQUEST', `walkDuration must be one of: ${VALID_WALKING_COURSE_DURATIONS.join(', ')}`)
    );
  }
  // The start point is optional, but a half-specified one is a client bug
  // rather than "no start point", so it's rejected instead of ignored.
  const hasLatitude = startLatitude !== undefined;
  const hasLongitude = startLongitude !== undefined;
  if (hasLatitude !== hasLongitude) {
    return next(
      new AppError(400, 'INVALID_REQUEST', 'startLatitude and startLongitude must be provided together')
    );
  }
  if (hasLatitude) {
    if (typeof startLatitude !== 'number' || startLatitude < -90 || startLatitude > 90) {
      return next(new AppError(400, 'INVALID_REQUEST', 'startLatitude must be a number between -90 and 90'));
    }
    if (typeof startLongitude !== 'number' || startLongitude < -180 || startLongitude > 180) {
      return next(new AppError(400, 'INVALID_REQUEST', 'startLongitude must be a number between -180 and 180'));
    }
  }
  if (startName !== undefined && (typeof startName !== 'string' || startName.length > 100)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'startName must be a string of at most 100 characters'));
  }
  if (
    avoidPlaceIds !== undefined &&
    (!Array.isArray(avoidPlaceIds) ||
      avoidPlaceIds.length > MAX_AVOID_PLACE_IDS ||
      !avoidPlaceIds.every((id) => typeof id === 'string'))
  ) {
    return next(
      new AppError(400, 'INVALID_REQUEST', `avoidPlaceIds must be an array of at most ${MAX_AVOID_PLACE_IDS} strings`)
    );
  }
  return next();
}

const MAX_SIMILAR_TASTE_LIMIT = 50;

function validateSimilarTasteLimit(req, res, next) {
  const { limit } = req.query;
  if (limit !== undefined) {
    const parsed = Number(limit);
    if (!Number.isFinite(parsed) || parsed <= 0 || parsed > MAX_SIMILAR_TASTE_LIMIT) {
      return next(new AppError(400, 'INVALID_REQUEST', `limit must be between 1 and ${MAX_SIMILAR_TASTE_LIMIT}`));
    }
  }
  return next();
}

module.exports = {
  validateNearbyRequest,
  VALID_NEARBY_CATEGORY_GROUPS,
  validateWalkingCourseRequest,
  validateSimilarTasteLimit,
  VALID_WALKING_COURSE_MOODS,
  VALID_WALKING_COURSE_DURATIONS,
};
