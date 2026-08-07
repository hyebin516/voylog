const express = require('express');
const videoRoutes = require('./video.routes');
const bookmarkRoutes = require('./bookmark.routes');
const bookmarkFolderRoutes = require('./bookmark-folder.routes');
const hotelRoutes = require('./hotel.routes');
const itineraryRoutes = require('./itinerary.routes');
const tripRoutes = require('./trip.routes');
const notificationSettingsRoutes = require('./notification-settings.routes');
const recommendationRoutes = require('./recommendation.routes');
const authRoutes = require('./auth.routes');

const router = express.Router();

router.use('/videos', videoRoutes);
router.use('/bookmarks', bookmarkRoutes);
router.use('/bookmark-folders', bookmarkFolderRoutes);
router.use('/hotels', hotelRoutes);
router.use('/itineraries', itineraryRoutes);
router.use('/trips', tripRoutes);
router.use('/notification-settings', notificationSettingsRoutes);
router.use('/recommendations', recommendationRoutes);
router.use('/auth', authRoutes);

module.exports = router;
