const jwt = require('jsonwebtoken');
const env = require('../config/env');

/**
 * Attaches req.user when a valid Bearer token is present, but never rejects
 * the request otherwise. Used by endpoints that must work for guests (e.g.
 * nearby recommendations) while still personalizing for logged-in users.
 */
function optionalAuthenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next();
  }

  const token = header.slice('Bearer '.length);
  try {
    req.user = jwt.verify(token, env.jwtSecret);
  } catch (err) {
    // Invalid/expired token on an optional-auth route: fall back to a
    // guest request instead of rejecting.
  }
  return next();
}

module.exports = optionalAuthenticate;
