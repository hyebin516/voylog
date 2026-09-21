const deviceTokenRepository = require('../repositories/device-token.repository');
const { success } = require('../utils/response');

/**
 * FR-12 push notifications: the app hands its FCM registration token over
 * after login, and takes it back on logout. There is no business logic to
 * put in a service -- this is a two-row table the app owns.
 */
async function register(req, res, next) {
  try {
    const { token, platform } = req.body;
    await deviceTokenRepository.upsert(req.user.userId, token, platform);
    return success(res, { registered: true }, 201);
  } catch (err) {
    return next(err);
  }
}

async function remove(req, res, next) {
  try {
    // Deleting by token alone is deliberate: a token is a device, and a
    // device that is signing out should stop receiving notifications even
    // if the row is claimed by whoever logged in on it last.
    await deviceTokenRepository.remove(req.params.token);
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { register, remove };
