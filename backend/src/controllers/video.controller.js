const videoService = require('../services/video.service');
const { success } = require('../utils/response');

async function analyze(req, res, next) {
  try {
    const { youtubeUrl } = req.body;
    const result = await videoService.analyzeVideo(youtubeUrl);
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

module.exports = { analyze };
