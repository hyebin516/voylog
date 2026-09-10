const express = require('express');
const itineraryController = require('../controllers/itinerary.controller');
const { validateCreateItinerary, validateItineraryId } = require('../validators/itinerary.validator');
const { validatePublishTitle } = require('../validators/shared-route.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateCreateItinerary, itineraryController.create);
router.post('/:id/publish', validateItineraryId, validatePublishTitle, itineraryController.publish);

module.exports = router;
