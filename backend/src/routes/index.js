const express = require('express');
const videoRoutes = require('./video.routes');
const bookmarkRoutes = require('./bookmark.routes');
const hotelRoutes = require('./hotel.routes');
const itineraryRoutes = require('./itinerary.routes');
const tripRoutes = require('./trip.routes');
const authRoutes = require('./auth.routes');

const router = express.Router();

router.use('/videos', videoRoutes);
router.use('/bookmarks', bookmarkRoutes);
router.use('/hotels', hotelRoutes);
router.use('/itineraries', itineraryRoutes);
router.use('/trips', tripRoutes);
router.use('/auth', authRoutes);

module.exports = router;
