const express = require('express');
const tripController = require('../controllers/trip.controller');
const { validateCreateTrip, validateTripId } = require('../validators/trip.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateCreateTrip, tripController.create);
router.get('/', tripController.list);
router.get('/:id', validateTripId, tripController.get);
router.delete('/:id', validateTripId, tripController.remove);

module.exports = router;
