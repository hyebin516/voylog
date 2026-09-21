const AppError = require('../utils/AppError');

const PLATFORMS = ['android', 'ios'];

function validateRegisterDeviceToken(req, res, next) {
  const { token, platform } = req.body;
  if (typeof token !== 'string' || !token.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'token is required'));
  }
  if (!PLATFORMS.includes(platform)) {
    return next(new AppError(400, 'INVALID_REQUEST', `platform must be one of: ${PLATFORMS.join(', ')}`));
  }
  return next();
}

module.exports = { validateRegisterDeviceToken };
