const AppError = require('../utils/AppError');

function validateKakaoLogin(req, res, next) {
  const { kakaoAccessToken } = req.body;
  if (!kakaoAccessToken || typeof kakaoAccessToken !== 'string') {
    return next(new AppError(400, 'INVALID_REQUEST', 'kakaoAccessToken is required'));
  }
  return next();
}

module.exports = { validateKakaoLogin };
