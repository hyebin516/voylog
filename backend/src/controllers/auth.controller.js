const authService = require('../services/auth.service');
const { success } = require('../utils/response');

function toUserResponse(user) {
  return {
    userId: user.user_id,
    email: user.email,
    nickname: user.nickname,
    profileImage: user.profile_image,
  };
}

async function kakaoLogin(req, res, next) {
  try {
    const { token, user } = await authService.kakaoLogin(req.body.kakaoAccessToken);
    return success(res, { token, user: toUserResponse(user) });
  } catch (err) {
    return next(err);
  }
}

async function profile(req, res, next) {
  try {
    const user = await authService.getProfile(req.user.userId);
    return success(res, toUserResponse(user));
  } catch (err) {
    return next(err);
  }
}

module.exports = { kakaoLogin, profile };
