const express = require('express');
const authController = require('../controllers/auth.controller');
const { validateKakaoLogin } = require('../validators/auth.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.post('/kakao', validateKakaoLogin, authController.kakaoLogin);
router.get('/profile', authenticate, authController.profile);

module.exports = router;
