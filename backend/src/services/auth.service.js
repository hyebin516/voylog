const axios = require('axios');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const env = require('../config/env');
const userRepository = require('../repositories/user.repository');
const emailOtpRepository = require('../repositories/email-otp.repository');
const emailService = require('../services/email.service');
const AppError = require('../utils/AppError');

async function fetchKakaoProfile(kakaoAccessToken) {
  try {
    const { data } = await axios.get('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${kakaoAccessToken}` },
    });
    return {
      providerId: String(data.id),
      email: data.kakao_account?.email ?? null,
      nickname: data.kakao_account?.profile?.nickname ?? 'Kakao User',
      profileImage: data.kakao_account?.profile?.profile_image_url ?? null,
    };
  } catch (err) {
    throw new AppError(503, 'AI_PROVIDER_ERROR', 'Failed to verify Kakao access token');
  }
}

function issueJwt(user) {
  return jwt.sign({ userId: user.user_id }, env.jwtSecret, { expiresIn: env.jwtExpiresIn });
}

async function kakaoLogin(kakaoAccessToken) {
  const profile = await fetchKakaoProfile(kakaoAccessToken);

  let user = await userRepository.findByProviderId(profile.providerId);
  if (!user) {
    user = await userRepository.create(profile);
  }

  const token = issueJwt(user);
  return { token, user };
}

async function getProfile(userId) {
  const user = await userRepository.findById(userId);
  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }
  return user;
}

async function deleteAccount(userId) {
  await userRepository.softDelete(userId);
}

function generateOtpCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

function hashOtpCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

async function requestSignupOtp(email) {
  const existingUser = await userRepository.findByEmail(email);
  if (existingUser) {
    throw new AppError(409, 'EMAIL_EXISTS', 'This email is already registered');
  }

  const code = generateOtpCode();
  await emailOtpRepository.create(email, hashOtpCode(code));
  await emailService.sendOtpEmail(email, code);
}

async function verifySignupOtp(email, code) {
  const otp = await emailOtpRepository.findLatestUnverifiedByEmail(email);
  if (!otp || otp.expires_at < new Date()) {
    throw new AppError(400, 'OTP_EXPIRED', 'The verification code has expired');
  }
  if (otp.attempts >= emailOtpRepository.MAX_ATTEMPTS) {
    throw new AppError(400, 'OTP_EXPIRED', 'Too many incorrect attempts, request a new code');
  }
  if (otp.code_hash !== hashOtpCode(code)) {
    await emailOtpRepository.incrementAttempts(otp.otp_id);
    throw new AppError(400, 'OTP_INVALID', 'The verification code is incorrect');
  }

  await emailOtpRepository.markVerified(otp.otp_id);
}

async function signup(email, password, nickname) {
  const existingUser = await userRepository.findByEmail(email);
  if (existingUser) {
    throw new AppError(409, 'EMAIL_EXISTS', 'This email is already registered');
  }

  const verifiedOtp = await emailOtpRepository.findLatestVerifiedByEmail(email);
  if (!verifiedOtp) {
    throw new AppError(400, 'OTP_NOT_VERIFIED', 'Please verify your email before signing up');
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await userRepository.createEmailUser({ email, passwordHash, nickname });
  await emailOtpRepository.deleteByEmail(email);

  const token = issueJwt(user);
  return { token, user };
}

async function login(email, password) {
  const user = await userRepository.findByEmail(email);
  if (!user || !user.password_hash || !(await bcrypt.compare(password, user.password_hash))) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
  }

  const token = issueJwt(user);
  return { token, user };
}

module.exports = {
  kakaoLogin,
  getProfile,
  deleteAccount,
  requestSignupOtp,
  verifySignupOtp,
  signup,
  login,
};
