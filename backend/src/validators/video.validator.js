const AppError = require('../utils/AppError');

const YOUTUBE_URL_PATTERN = /^https?:\/\/(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)[\w-]{11}/;

function validateAnalyzeRequest(req, res, next) {
  const { youtubeUrl } = req.body;

  if (!youtubeUrl || typeof youtubeUrl !== 'string' || !YOUTUBE_URL_PATTERN.test(youtubeUrl)) {
    return next(new AppError(400, 'INVALID_URL', 'A valid YouTube URL is required'));
  }

  return next();
}

function validateSearchRequest(req, res, next) {
  const { hashtag } = req.query;

  if (!hashtag || typeof hashtag !== 'string' || !hashtag.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty hashtag query parameter is required'));
  }

  return next();
}

const VALID_DURATIONS = ['당일치기', '1박2일', '2박3일', '3박4일', '4박5일이상'];

function isNonEmptyStringArray(value) {
  return Array.isArray(value) && value.length > 0 && value.every((v) => typeof v === 'string' && v.trim());
}

function validateRecommendationRequest(req, res, next) {
  const { regions, themes, duration } = req.body;

  if (!isNonEmptyStringArray(regions)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'At least one region is required'));
  }

  if (!isNonEmptyStringArray(themes)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'At least one theme is required'));
  }

  if (!VALID_DURATIONS.includes(duration)) {
    return next(new AppError(400, 'INVALID_REQUEST', `duration must be one of: ${VALID_DURATIONS.join(', ')}`));
  }

  return next();
}

module.exports = { validateAnalyzeRequest, validateSearchRequest, validateRecommendationRequest, VALID_DURATIONS };
