const videoService = require('../services/video.service');
const { success } = require('../utils/response');

async function analyze(req, res, next) {
  try {
    const { youtubeUrl } = req.body;
    // Optional auth: guests can analyze too, they just get no push.
    const result = await videoService.analyzeVideo(youtubeUrl, req.user ? req.user.userId : null);
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

async function search(req, res, next) {
  try {
    const { hashtag } = req.query;
    const result = await videoService.searchByHashtag(hashtag);
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

async function recommendations(req, res, next) {
  try {
    const { regions, themes, duration } = req.body;
    const result = await videoService.getRecommendations(regions, themes, duration);
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

module.exports = { analyze, search, recommendations };
