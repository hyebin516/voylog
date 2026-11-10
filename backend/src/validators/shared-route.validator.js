const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateSharedRouteId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid shared route id is required'));
  }
  return next();
}

function validatePublishTitle(req, res, next) {
  const { title } = req.body;
  if (typeof title !== 'string' || title.trim().length === 0 || title.length > 100) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty title of at most 100 characters is required'));
  }
  return next();
}

// Kept in step with the CHECK constraint in migration 033.
const REPORT_REASONS = ['spam', 'offensive', 'sexual', 'illegal', 'copyright', 'other'];

function validateReport(req, res, next) {
  const { reason, detail } = req.body;
  if (!REPORT_REASONS.includes(reason)) {
    return next(new AppError(400, 'INVALID_REQUEST', `reason must be one of: ${REPORT_REASONS.join(', ')}`));
  }
  // Optional. A reason on its own is a complete report.
  if (detail !== undefined && detail !== null && (typeof detail !== 'string' || detail.length > 1000)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'detail must be a string of at most 1000 characters'));
  }
  return next();
}

module.exports = { validateSharedRouteId, validatePublishTitle, validateReport, REPORT_REASONS };
