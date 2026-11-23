const express = require('express');
const videoController = require('../controllers/video.controller');
const videoService = require('../services/video.service');
const optionalAuthenticate = require('../middlewares/optionalAuth');
const { createAnalyzeLimiter } = require('../middlewares/rateLimit');
const {
  validateAnalyzeRequest,
  validateSearchRequest,
  validateRecommendationRequest,
} = require('../validators/video.validator');

const router = express.Router();

// Order matters: the limiter needs to know who is asking (optional auth) and
// which video (a validated URL) before it decides whether to count.
const analyzeLimiter = createAnalyzeLimiter({ isFreeRequest: videoService.isAlreadyAnalyzed });

router.post('/analyze', optionalAuthenticate, validateAnalyzeRequest, analyzeLimiter, videoController.analyze);
router.get('/search', validateSearchRequest, videoController.search);
router.post('/recommendations', validateRecommendationRequest, videoController.recommendations);

module.exports = router;
