const express = require('express');
const videoController = require('../controllers/video.controller');
const {
  validateAnalyzeRequest,
  validateSearchRequest,
  validateRecommendationRequest,
} = require('../validators/video.validator');

const router = express.Router();

router.post('/analyze', validateAnalyzeRequest, videoController.analyze);
router.get('/search', validateSearchRequest, videoController.search);
router.post('/recommendations', validateRecommendationRequest, videoController.recommendations);

module.exports = router;
