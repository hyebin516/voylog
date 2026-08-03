const express = require('express');
const hotelController = require('../controllers/hotel.controller');
const { validateCreateHotel, validateHotelId } = require('../validators/hotel.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateCreateHotel, hotelController.create);
router.get('/', hotelController.list);
router.put('/:id', validateHotelId, validateCreateHotel, hotelController.update);
router.delete('/:id', validateHotelId, hotelController.remove);

module.exports = router;
