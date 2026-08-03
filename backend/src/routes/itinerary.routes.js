const express = require('express');
const itineraryController = require('../controllers/itinerary.controller');
const { validateCreateItinerary } = require('../validators/itinerary.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateCreateItinerary, itineraryController.create);

module.exports = router;
