const express = require('express');
const videoController = require('../controllers/video.controller');
const { validateAnalyzeRequest } = require('../validators/video.validator');

const router = express.Router();

router.post('/analyze', validateAnalyzeRequest, videoController.analyze);

module.exports = router;
