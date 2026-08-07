const express = require('express');
const recommendationController = require('../controllers/recommendation.controller');
const { validateNearbyRequest } = require('../validators/recommendation.validator');
const optionalAuthenticate = require('../middlewares/optionalAuth');

const router = express.Router();

router.post('/nearby', optionalAuthenticate, validateNearbyRequest, recommendationController.nearby);

module.exports = router;
