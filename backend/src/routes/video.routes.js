const express = require('express');
const videoController = require('../controllers/video.controller');
const optionalAuthenticate = require('../middlewares/optionalAuth');
const {
  validateAnalyzeRequest,
  validateSearchRequest,
  validateRecommendationRequest,
} = require('../validators/video.validator');

const router = express.Router();

router.post('/analyze', optionalAuthenticate, validateAnalyzeRequest, videoController.analyze);
router.get('/search', validateSearchRequest, videoController.search);
router.post('/recommendations', validateRecommendationRequest, videoController.recommendations);

module.exports = router;
