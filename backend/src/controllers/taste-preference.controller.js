const tastePreferenceService = require('../services/taste-preference.service');
const { success } = require('../utils/response');

async function get(req, res, next) {
  try {
    const preferences = await tastePreferenceService.getPreferences(req.user.userId);
    return success(res, preferences);
  } catch (err) {
    return next(err);
  }
}

async function update(req, res, next) {
  try {
    const preferences = await tastePreferenceService.setPreferences(req.user.userId, req.body.tags);
    return success(res, preferences);
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    await tastePreferenceService.clearPreferences(req.user.userId);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { get, update, remove };
