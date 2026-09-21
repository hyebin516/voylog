const express = require('express');
const deviceTokenController = require('../controllers/device-token.controller');
const { validateRegisterDeviceToken } = require('../validators/device-token.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateRegisterDeviceToken, deviceTokenController.register);
router.delete('/:token', deviceTokenController.remove);

module.exports = router;
