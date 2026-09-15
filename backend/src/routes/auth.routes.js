const express = require('express');
const authController = require('../controllers/auth.controller');
const {
  validateKakaoLogin,
  validateRequestOtp,
  validateVerifyOtp,
  validateSignup,
  validateLogin,
  validateUpdateNickname,
  validateCheckNickname,
  validateChangePassword,
  validateResetPassword,
} = require('../validators/auth.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.post('/kakao', validateKakaoLogin, authController.kakaoLogin);
router.get('/check-nickname', validateCheckNickname, authController.checkNickname);
router.post('/signup/request-otp', validateRequestOtp, authController.requestOtp);
router.post('/signup/verify-otp', validateVerifyOtp, authController.verifyOtp);
router.post('/signup', validateSignup, authController.signup);
router.post('/login', validateLogin, authController.login);
router.get('/profile', authenticate, authController.profile);
router.patch('/profile', authenticate, validateUpdateNickname, authController.updateProfile);
router.patch('/password', authenticate, validateChangePassword, authController.changePassword);
router.post('/password/reset/request-otp', validateRequestOtp, authController.requestPasswordResetOtp);
router.post('/password/reset/verify-otp', validateVerifyOtp, authController.verifyPasswordResetOtp);
router.post('/password/reset', validateResetPassword, authController.resetPassword);
router.delete('/profile', authenticate, authController.deleteAccount);

module.exports = router;
