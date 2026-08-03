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

module.exports = { validateAnalyzeRequest, validateSearchRequest };
