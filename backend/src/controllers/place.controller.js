const placeSummaryService = require('../services/place-summary.service');
const { success } = require('../utils/response');

async function summary(req, res, next) {
  try {
    const result = await placeSummaryService.getPlaceSummary(req.params.id);
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

module.exports = { summary };
