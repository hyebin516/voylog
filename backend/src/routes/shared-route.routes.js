const express = require('express');
const sharedRouteController = require('../controllers/shared-route.controller');
const { validateSharedRouteId, validatePublishTitle } = require('../validators/shared-route.validator');
const optionalAuthenticate = require('../middlewares/optionalAuth');
const authenticate = require('../middlewares/auth');

const router = express.Router();

// Guests can browse the feed (no match %); logged-in users see their own
// posts included (with isOwner:true, no match %) alongside everyone else's.
router.get('/shared', optionalAuthenticate, sharedRouteController.feed);
router.post('/:id/like', authenticate, validateSharedRouteId, sharedRouteController.like);
router.delete('/:id/like', authenticate, validateSharedRouteId, sharedRouteController.unlike);
router.patch('/:id', authenticate, validateSharedRouteId, validatePublishTitle, sharedRouteController.update);
router.delete('/:id', authenticate, validateSharedRouteId, sharedRouteController.unpublish);

module.exports = router;
