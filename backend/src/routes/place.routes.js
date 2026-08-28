const express = require('express');
const placeController = require('../controllers/place.controller');
const { validatePlaceId } = require('../validators/place.validator');

const router = express.Router();

router.get('/:id/summary', validatePlaceId, placeController.summary);

module.exports = router;
