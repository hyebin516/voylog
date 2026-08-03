const axios = require('axios');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const userRepository = require('../repositories/user.repository');
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

module.exports = { kakaoLogin, getProfile, deleteAccount };
