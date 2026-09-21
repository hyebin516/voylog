const express = require('express');
const videoRoutes = require('./video.routes');
const placeRoutes = require('./place.routes');
const bookmarkRoutes = require('./bookmark.routes');
const bookmarkFolderRoutes = require('./bookmark-folder.routes');
const hotelRoutes = require('./hotel.routes');
const itineraryRoutes = require('./itinerary.routes');
const tripRoutes = require('./trip.routes');
const notificationSettingsRoutes = require('./notification-settings.routes');
const deviceTokenRoutes = require('./device-token.routes');
const supportInquiryRoutes = require('./support-inquiry.routes');
const recommendationRoutes = require('./recommendation.routes');
const tastePreferenceRoutes = require('./taste-preference.routes');
const savedWalkingCourseRoutes = require('./saved-walking-course.routes');
const sharedRouteRoutes = require('./shared-route.routes');
const authRoutes = require('./auth.routes');

const router = express.Router();

router.use('/videos', videoRoutes);
router.use('/places', placeRoutes);
router.use('/bookmarks', bookmarkRoutes);
router.use('/bookmark-folders', bookmarkFolderRoutes);
router.use('/hotels', hotelRoutes);
router.use('/itineraries', itineraryRoutes);
router.use('/trips', tripRoutes);
router.use('/notification-settings', notificationSettingsRoutes);
router.use('/device-tokens', deviceTokenRoutes);
router.use('/support-inquiries', supportInquiryRoutes);
router.use('/recommendations', recommendationRoutes);
router.use('/taste-preferences', tastePreferenceRoutes);
router.use('/walking-courses', savedWalkingCourseRoutes);
router.use('/routes', sharedRouteRoutes);
router.use('/auth', authRoutes);

module.exports = router;
