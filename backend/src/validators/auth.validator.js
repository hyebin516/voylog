const AppError = require('../utils/AppError');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isValidEmail(email) {
  return typeof email === 'string' && EMAIL_PATTERN.test(email);
}

function validateKakaoLogin(req, res, next) {
  const { kakaoAccessToken } = req.body;
  if (!kakaoAccessToken || typeof kakaoAccessToken !== 'string') {
    return next(new AppError(400, 'INVALID_REQUEST', 'kakaoAccessToken is required'));
  }
  return next();
}

function validateRequestOtp(req, res, next) {
  if (!isValidEmail(req.body.email)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid email is required'));
  }
  return next();
}

function validateVerifyOtp(req, res, next) {
  const { email, code } = req.body;
  if (!isValidEmail(email)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid email is required'));
  }
  if (typeof code !== 'string' || !/^\d{6}$/.test(code)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A 6-digit verification code is required'));
  }
  return next();
}

function validateSignup(req, res, next) {
  const { email, password, nickname } = req.body;
  if (!isValidEmail(email)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid email is required'));
  }
  if (typeof password !== 'string' || password.length < 8) {
    return next(new AppError(400, 'INVALID_REQUEST', 'Password must be at least 8 characters'));
  }
  if (!nickname || typeof nickname !== 'string' || !nickname.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty nickname is required'));
  }
  return next();
}

function validateLogin(req, res, next) {
  const { email, password } = req.body;
  if (!isValidEmail(email)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid email is required'));
  }
  if (typeof password !== 'string' || !password) {
    return next(new AppError(400, 'INVALID_REQUEST', 'Password is required'));
  }
  return next();
}

module.exports = {
  validateKakaoLogin,
  validateRequestOtp,
  validateVerifyOtp,
  validateSignup,
  validateLogin,
};
