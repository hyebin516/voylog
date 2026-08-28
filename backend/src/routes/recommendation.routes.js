const express = require('express');
const recommendationController = require('../controllers/recommendation.controller');
const behaviorController = require('../controllers/behavior.controller');
const {
  validateNearbyRequest,
  validateWalkingCourseRequest,
  validateSimilarTasteLimit,
} = require('../validators/recommendation.validator');
const { validateRecordBehavior } = require('../validators/behavior.validator');
const optionalAuthenticate = require('../middlewares/optionalAuth');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.post('/nearby', optionalAuthenticate, validateNearbyRequest, recommendationController.nearby);
router.post(
  '/walking-course',
  optionalAuthenticate,
  validateWalkingCourseRequest,
  recommendationController.walkingCourse
);
// Needs a real user both ways: to know whose taste to compare, and because
// "similar to me" is meaningless for a guest.
router.get('/similar-taste', authenticate, validateSimilarTasteLimit, recommendationController.similarTaste);
// Behavior tracking always needs a real user -- it feeds that user's own
// preference vector/tag_scores, so anonymous requests aren't meaningful here.
router.post('/behaviors', authenticate, validateRecordBehavior, behaviorController.record);

module.exports = router;
