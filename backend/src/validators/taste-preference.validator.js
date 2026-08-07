const AppError = require('../utils/AppError');

function validateSetPreferences(req, res, next) {
  const { tags } = req.body;
  if (!Array.isArray(tags) || tags.length === 0 || !tags.every((tag) => typeof tag === 'string' && tag.trim())) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty array of tag strings is required'));
  }
  return next();
}

module.exports = { validateSetPreferences };
