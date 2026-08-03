const express = require('express');
const videoController = require('../controllers/video.controller');
const { validateAnalyzeRequest, validateSearchRequest } = require('../validators/video.validator');

const router = express.Router();

router.post('/analyze', validateAnalyzeRequest, videoController.analyze);
router.get('/search', validateSearchRequest, videoController.search);

module.exports = router;
