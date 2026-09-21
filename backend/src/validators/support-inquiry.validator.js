const AppError = require('../utils/AppError');

const CATEGORIES = ['analysis', 'route', 'account', 'bug', 'other'];
const MESSAGE_MAX_LENGTH = 2000;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateSubmitInquiry(req, res, next) {
  const { email, category, message } = req.body;

  if (typeof email !== 'string' || !EMAIL_PATTERN.test(email.trim())) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid email is required to reply to'));
  }
  if (!CATEGORIES.includes(category)) {
    return next(new AppError(400, 'INVALID_REQUEST', `category must be one of: ${CATEGORIES.join(', ')}`));
  }
  if (typeof message !== 'string' || !message.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'message is required'));
  }
  if (message.trim().length > MESSAGE_MAX_LENGTH) {
    return next(new AppError(400, 'INVALID_REQUEST', `message must be at most ${MESSAGE_MAX_LENGTH} characters`));
  }

  req.body.email = email.trim();
  req.body.message = message.trim();
  return next();
}

module.exports = { validateSubmitInquiry, CATEGORIES, MESSAGE_MAX_LENGTH };
