const express = require('express');
const hotelController = require('../controllers/hotel.controller');
const {
  validateCreateHotel,
  validateHotelId,
  validateHotelSearchQuery,
  validateReverseGeocodeQuery,
} = require('../validators/hotel.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.get('/search', validateHotelSearchQuery, hotelController.search);
router.get('/reverse-geocode', validateReverseGeocodeQuery, hotelController.reverseGeocode);
router.post('/', validateCreateHotel, hotelController.create);
router.get('/', hotelController.list);
router.put('/:id', validateHotelId, validateCreateHotel, hotelController.update);
router.delete('/:id', validateHotelId, hotelController.remove);

module.exports = router;
