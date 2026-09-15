const authService = require('../services/auth.service');
const { success } = require('../utils/response');

function toUserResponse(user) {
  return {
    userId: user.user_id,
    email: user.email,
    nickname: user.nickname,
    profileImage: user.profile_image,
    provider: user.provider,
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

async function deleteAccount(req, res, next) {
  try {
    await authService.deleteAccount(req.user.userId);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

async function updateProfile(req, res, next) {
  try {
    const user = await authService.updateNickname(req.user.userId, req.body.nickname);
    return success(res, toUserResponse(user));
  } catch (err) {
    return next(err);
  }
}

async function checkNickname(req, res, next) {
  try {
    const result = await authService.checkNicknameAvailability(req.query.nickname);
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

async function requestOtp(req, res, next) {
  try {
    await authService.requestSignupOtp(req.body.email);
    return success(res, {});
  } catch (err) {
    return next(err);
  }
}

async function verifyOtp(req, res, next) {
  try {
    await authService.verifySignupOtp(req.body.email, req.body.code);
    return success(res, {});
  } catch (err) {
    return next(err);
  }
}

async function signup(req, res, next) {
  try {
    const { token, user } = await authService.signup(req.body.email, req.body.password, req.body.nickname);
    return success(res, { token, user: toUserResponse(user) }, 201);
  } catch (err) {
    return next(err);
  }
}

async function login(req, res, next) {
  try {
    const { token, user } = await authService.login(req.body.email, req.body.password);
    return success(res, { token, user: toUserResponse(user) });
  } catch (err) {
    return next(err);
  }
}

async function changePassword(req, res, next) {
  try {
    await authService.changePassword(req.user.userId, req.body.currentPassword, req.body.newPassword);
    return success(res, {});
  } catch (err) {
    return next(err);
  }
}

async function requestPasswordResetOtp(req, res, next) {
  try {
    await authService.requestPasswordResetOtp(req.body.email);
    return success(res, {});
  } catch (err) {
    return next(err);
  }
}

async function verifyPasswordResetOtp(req, res, next) {
  try {
    await authService.verifyPasswordResetOtp(req.body.email, req.body.code);
    return success(res, {});
  } catch (err) {
    return next(err);
  }
}

async function resetPassword(req, res, next) {
  try {
    await authService.resetPassword(req.body.email, req.body.newPassword);
    return success(res, {});
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  kakaoLogin,
  profile,
  deleteAccount,
  updateProfile,
  checkNickname,
  requestOtp,
  verifyOtp,
  signup,
  login,
  changePassword,
  requestPasswordResetOtp,
  verifyPasswordResetOtp,
  resetPassword,
};
