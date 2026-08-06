const express = require('express');
const notificationSettingsController = require('../controllers/notification-settings.controller');
const { validateUpdateNotificationSettings } = require('../validators/notification-settings.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.get('/', notificationSettingsController.get);
router.put('/', validateUpdateNotificationSettings, notificationSettingsController.update);

module.exports = router;
