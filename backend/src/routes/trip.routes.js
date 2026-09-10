const express = require('express');
const tripController = require('../controllers/trip.controller');
const { validateCreateTrip, validateTripId, validateUpdateTripDates } = require('../validators/trip.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

// Public, unauthenticated: the trip owner hands this link out directly, so
// anyone holding it can view a read-only share page -- must be registered
// before `authenticate` below, which guards every other trip route.
router.get('/:id/share', validateTripId, tripController.share);

router.use(authenticate);

router.post('/', validateCreateTrip, tripController.create);
router.get('/', tripController.list);
router.get('/:id', validateTripId, tripController.get);
router.patch('/:id', validateTripId, validateUpdateTripDates, tripController.updateDates);
router.delete('/:id', validateTripId, tripController.remove);

module.exports = router;
