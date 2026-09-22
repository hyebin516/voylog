const axios = require('axios');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const env = require('../config/env');
const userRepository = require('../repositories/user.repository');
const profileImageService = require('./profile-image.service');
const emailOtpRepository = require('../repositories/email-otp.repository');
const emailService = require('../services/email.service');
const AppError = require('../utils/AppError');

async function fetchKakaoProfile(kakaoAccessToken) {
  try {
    const { data } = await axios.get('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${kakaoAccessToken}` },
    });
    // Kakao answers 200 with the field simply absent when the user hasn't
    // consented, which is indistinguishable from "this account has none"
    // unless you read the companion *_needs_agreement flag. Without this
    // line a missing photo or email looks like a bug in our mapping.
    const account = data.kakao_account ?? {};
    const withheld = ['email', 'profile_image', 'profile_nickname']
      .filter((field) => account[`${field}_needs_agreement`] === true);
    if (withheld.length > 0) {
      console.warn(
        `Kakao withheld ${withheld.join(', ')} for this login: the user has not agreed to ` +
          'those consent items (Kakao only re-asks for optional items through loginWithNewScopes, ' +
          'or on a fresh consent after the app is unlinked)'
      );
    }

    return {
      providerId: String(data.id),
      email: account.email ?? null,
      nickname: account.profile?.nickname ?? 'Kakao User',
      profileImage: account.profile?.profile_image_url ?? null,
    };
  } catch (err) {
    // Kakao's own reason (KOE101 unregistered app/key hash, -401 expired
    // token, ...) is the only thing that says why a login failed; without
    // it every failure reaches the app as one opaque message. The access
    // token itself is never logged.
    const kakao = err.response?.data;
    console.warn(
      `Kakao profile lookup failed: status=${err.response?.status ?? 'none'} ` +
        `code=${kakao?.code ?? '-'} msg=${kakao?.msg ?? err.message}`
    );
    throw new AppError(503, 'AI_PROVIDER_ERROR', 'Failed to verify Kakao access token');
  }
}

function issueJwt(user) {
  return jwt.sign({ userId: user.user_id }, env.jwtSecret, { expiresIn: env.jwtExpiresIn });
}

// Kakao's own profile nickname isn't guaranteed unique across this app's
// users, but the one-tap Kakao login flow can't stop and ask the user to
// pick a different one the way native signup does -- so on a collision we
// silently append a numeric suffix until it's free.
async function resolveUniqueNickname(baseNickname) {
  let candidate = baseNickname;
  let suffix = 2;
  while (await userRepository.findByNickname(candidate)) {
    candidate = `${baseNickname}${suffix}`;
    suffix += 1;
  }
  return candidate;
}

/**
 * Pulls Kakao's email onto a returning user's row when it changed --
 * typically when the email consent item was only added to the Kakao app
 * later, so the account was created without it.
 *
 * Two fields are deliberately NOT synced. The nickname is ours once created
 * (renameable in the app, unique per user). The profile photo is the user's
 * own: they set it from their gallery, so re-syncing Kakao's would silently
 * undo that on the next login. Kakao's photo is still used as the starting
 * value when the account is first created.
 *
 * Best-effort. A sync failure -- most plausibly another account already
 * holding that email -- must not stop someone from logging in.
 */
async function refreshKakaoProfile(user, profile) {
  const emailChanged = profile.email != null && profile.email !== user.email;
  if (!emailChanged) return null;

  try {
    return await userRepository.updateKakaoProfile(user.user_id, {
      email: profile.email,
      profileImage: user.profile_image,
    });
  } catch (err) {
    console.warn(`Kakao profile sync skipped for user ${user.user_id}: ${err.message}`);
    return null;
  }
}

async function kakaoLogin(kakaoAccessToken) {
  const profile = await fetchKakaoProfile(kakaoAccessToken);

  let user = await userRepository.findByProviderId(profile.providerId);
  if (!user) {
    const nickname = await resolveUniqueNickname(profile.nickname);
    user = await userRepository.create({ ...profile, nickname });
  } else {
    user = (await refreshKakaoProfile(user, profile)) || user;
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

async function updateNickname(userId, nickname) {
  const user = await userRepository.findById(userId);
  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }
  if (nickname !== user.nickname) {
    const existing = await userRepository.findByNickname(nickname);
    if (existing) {
      throw new AppError(409, 'NICKNAME_EXISTS', 'This nickname is already taken');
    }
  }
  return userRepository.updateNickname(userId, nickname);
}

async function checkNicknameAvailability(nickname) {
  const existing = await userRepository.findByNickname(nickname);
  return { available: !existing };
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

async function verifyOtpCode(email, code) {
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

async function verifySignupOtp(email, code) {
  return verifyOtpCode(email, code);
}

async function requestPasswordResetOtp(email) {
  const user = await userRepository.findByEmail(email);
  if (!user) {
    throw new AppError(404, 'EMAIL_NOT_FOUND', 'No account is registered with this email');
  }
  if (!user.password_hash) {
    throw new AppError(400, 'NO_PASSWORD_SET', 'This account has no password to reset (signed up via Kakao)');
  }

  const code = generateOtpCode();
  await emailOtpRepository.create(email, hashOtpCode(code));
  await emailService.sendOtpEmail(email, code);
}

async function verifyPasswordResetOtp(email, code) {
  return verifyOtpCode(email, code);
}

async function resetPassword(email, newPassword) {
  const user = await userRepository.findByEmail(email);
  if (!user || !user.password_hash) {
    throw new AppError(404, 'EMAIL_NOT_FOUND', 'No account is registered with this email');
  }

  const verifiedOtp = await emailOtpRepository.findLatestVerifiedByEmail(email);
  if (!verifiedOtp) {
    throw new AppError(400, 'OTP_NOT_VERIFIED', 'Please verify your email before resetting the password');
  }

  const passwordHash = await bcrypt.hash(newPassword, 10);
  await userRepository.updatePasswordHash(user.user_id, passwordHash);
  await emailOtpRepository.deleteByEmail(email);
}

async function signup(email, password, nickname) {
  const existingUser = await userRepository.findByEmail(email);
  if (existingUser) {
    throw new AppError(409, 'EMAIL_EXISTS', 'This email is already registered');
  }

  const existingNickname = await userRepository.findByNickname(nickname);
  if (existingNickname) {
    throw new AppError(409, 'NICKNAME_EXISTS', 'This nickname is already taken');
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

async function changePassword(userId, currentPassword, newPassword) {
  const user = await userRepository.findById(userId);
  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }
  if (!user.password_hash) {
    throw new AppError(400, 'NO_PASSWORD_SET', 'This account has no password to change (signed up via Kakao)');
  }
  if (!(await bcrypt.compare(currentPassword, user.password_hash))) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Current password is incorrect');
  }

  const passwordHash = await bcrypt.hash(newPassword, 10);
  return userRepository.updatePasswordHash(userId, passwordHash);
}

async function login(email, password) {
  const user = await userRepository.findByEmail(email);
  if (!user || !user.password_hash || !(await bcrypt.compare(password, user.password_hash))) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
  }

  const token = issueJwt(user);
  return { token, user };
}

/**
 * FR-08/FR-14 프로필 사진. The photo the user picked from their own gallery
 * replaces whatever was there, including a Kakao one.
 */
async function replaceProfileImage(userId, file) {
  const user = await getProfile(userId);
  return profileImageService.replaceProfileImage(user, file);
}

async function clearProfileImage(userId) {
  const user = await getProfile(userId);
  return profileImageService.clearProfileImage(user);
}

module.exports = {
  replaceProfileImage,
  clearProfileImage,
  kakaoLogin,
  getProfile,
  deleteAccount,
  updateNickname,
  checkNicknameAvailability,
  requestSignupOtp,
  verifySignupOtp,
  signup,
  login,
  changePassword,
  requestPasswordResetOtp,
  verifyPasswordResetOtp,
  resetPassword,
};
