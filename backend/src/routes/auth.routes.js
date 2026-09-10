const express = require('express');
const authController = require('../controllers/auth.controller');
const {
  validateKakaoLogin,
  validateRequestOtp,
  validateVerifyOtp,
  validateSignup,
  validateLogin,
  validateUpdateNickname,
} = require('../validators/auth.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.post('/kakao', validateKakaoLogin, authController.kakaoLogin);
router.post('/signup/request-otp', validateRequestOtp, authController.requestOtp);
router.post('/signup/verify-otp', validateVerifyOtp, authController.verifyOtp);
router.post('/signup', validateSignup, authController.signup);
router.post('/login', validateLogin, authController.login);
router.get('/profile', authenticate, authController.profile);
router.patch('/profile', authenticate, validateUpdateNickname, authController.updateProfile);
router.delete('/profile', authenticate, authController.deleteAccount);

module.exports = router;
