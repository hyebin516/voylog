const express = require('express');
const tastePreferenceController = require('../controllers/taste-preference.controller');
const { validateSetPreferences } = require('../validators/taste-preference.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.get('/', tastePreferenceController.get);
router.put('/', validateSetPreferences, tastePreferenceController.update);
router.delete('/', tastePreferenceController.remove);

module.exports = router;
