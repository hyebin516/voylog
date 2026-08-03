const jwt = require('jsonwebtoken');
const env = require('../config/env');
const AppError = require('../utils/AppError');

function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next(new AppError(401, 'JWT_INVALID', 'Authorization header is missing or malformed'));
  }

  const token = header.slice('Bearer '.length);

  try {
    req.user = jwt.verify(token, env.jwtSecret);
    return next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return next(new AppError(403, 'JWT_EXPIRED', 'JWT has expired'));
    }
    return next(new AppError(401, 'JWT_INVALID', 'JWT is invalid'));
  }
}

module.exports = authenticate;
