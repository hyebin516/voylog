const placeSummaryService = require('../services/place-summary.service');
const { success } = require('../utils/response');
const placeSearchService = require('../services/place-search.service');

async function summary(req, res, next) {
  try {
    const result = await placeSummaryService.getPlaceSummary(req.params.id);
    return success(res, result);
  } catch (err) {
    return next(err);
  }
}

async function search(req, res, next) {
  try {
    const places = await placeSearchService.searchForFolder(req.user.userId, req.query.query);
    return res.json(success({ places }));
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  search, summary };
