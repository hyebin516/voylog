const authService = require('../services/auth.service');
const profileImageService = require('../services/profile-image.service');
const { success } = require('../utils/response');

// [req] resolves an uploaded photo's stored path against the host the client
// reached us on; a Kakao photo is already absolute and passes through.
function toUserResponse(user, req) {
  return {
    userId: user.user_id,
    email: user.email,
    nickname: user.nickname,
    profileImage: profileImageService.toPublicUrl(user.profile_image, req),
    provider: user.provider,
  };
}

async function kakaoLogin(req, res, next) {
  try {
    const { token, user } = await authService.kakaoLogin(req.body.kakaoAccessToken);
    return success(res, { token, user: toUserResponse(user, req) });
  } catch (err) {
    return next(err);
  }
}

async function profile(req, res, next) {
  try {
    const user = await authService.getProfile(req.user.userId);
    return success(res, toUserResponse(user, req));
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
    return success(res, toUserResponse(user, req));
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
    return success(res, { token, user: toUserResponse(user, req) }, 201);
  } catch (err) {
    return next(err);
  }
}

async function login(req, res, next) {
  try {
    const { token, user } = await authService.login(req.body.email, req.body.password);
    return success(res, { token, user: toUserResponse(user, req) });
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


async function updateProfileImage(req, res, next) {
  try {
    const user = await authService.replaceProfileImage(req.user.userId, req.file);
    return success(res, toUserResponse(user, req));
  } catch (err) {
    return next(err);
  }
}

async function removeProfileImage(req, res, next) {
  try {
    const user = await authService.clearProfileImage(req.user.userId);
    return success(res, toUserResponse(user, req));
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  updateProfileImage,
  removeProfileImage,
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
