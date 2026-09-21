const express = require('express');
const supportInquiryController = require('../controllers/support-inquiry.controller');
const { validateSubmitInquiry } = require('../validators/support-inquiry.validator');
const authenticate = require('../middlewares/auth');
const optionalAuthenticate = require('../middlewares/optionalAuth');

const router = express.Router();

// Submitting works logged out; reading your own history obviously cannot.
router.post('/', optionalAuthenticate, validateSubmitInquiry, supportInquiryController.submit);
router.get('/', authenticate, supportInquiryController.list);

module.exports = router;
