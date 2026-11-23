const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

const { failure } = require('../utils/response');

// Rate limits exist here for one reason above all: `POST /videos/analyze`
// needs no login and spends money. Each call runs an LLM extraction and,
// for a video without subtitles, downloads frames and runs a vision model
// on them. Left open, one script can empty the OpenAI budget in minutes.
//
// Counting is per IP and in memory, which is enough for a single backend
// process. Running more than one instance would need a shared store
// (the package's Redis store) so the counters are not per-process.

function limiter({ windowMs, max, code, message }) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    // The app parses one failure envelope everywhere, so a rejection has to
    // look like every other error rather than the package's default body.
    handler: (req, res) => failure(res, 429, code, message),
  });
}

const ANALYZE_WINDOW_MS = 60 * 60 * 1000;
const ANALYZE_MAX_GUEST = 20;
const ANALYZE_MAX_USER = 100;

/**
 * The paid path (FR-01). Only requests that will actually run an analysis
 * count, and a logged-in caller is counted per account instead of per IP.
 *
 * It used to count every request per IP, before knowing who was asking or
 * whether the video was already analyzed. Two things broke in a live demo:
 * a logged-in user was refused exactly like a guest on the same hotspot,
 * and opening a video already in the cache -- free, no AI call -- spent the
 * same allowance. Worse, the app polls this endpoint every 5 seconds while
 * the background pass runs, so a single fresh analysis used up all 20 in
 * under two minutes.
 *
 * Must run after `optionalAuthenticate` (it reads `req.user`) and after the
 * URL validator (it looks the URL up). [isFreeRequest] answers "will this
 * be served without calling the AI worker?"; when it fails, the request is
 * counted -- a database hiccup should not open the paid path.
 *
 * Guests get their own error code so the app can offer login instead of a
 * dead-end error: signing in moves them to a separate, larger allowance.
 */
function createAnalyzeLimiter({ isFreeRequest }) {
  return rateLimit({
    windowMs: ANALYZE_WINDOW_MS,
    limit: (req) => (req.user ? ANALYZE_MAX_USER : ANALYZE_MAX_GUEST),
    keyGenerator: (req) => (req.user ? `user:${req.user.userId}` : `ip:${ipKeyGenerator(req.ip)}`),
    skip: async (req) => {
      try {
        return await isFreeRequest(req.body.youtubeUrl);
      } catch (err) {
        return false;
      }
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) =>
      req.user
        ? failure(res, 429, 'TOO_MANY_REQUESTS', '분석 요청이 너무 많아요. 잠시 후 다시 시도해 주세요.')
        : failure(
            res,
            429,
            'ANALYZE_LIMIT_GUEST',
            `로그인하지 않으면 1시간에 ${ANALYZE_MAX_GUEST}번까지 분석할 수 있어요. 로그인하면 계속 분석할 수 있어요.`
          ),
  });
}

/// Login, signup and the OTP mails. Protects against credential stuffing and
/// against someone using our SMTP account to send mail to strangers.
const authLimiter = limiter({
  windowMs: 15 * 60 * 1000,
  max: 30,
  code: 'TOO_MANY_REQUESTS',
  message: '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
});

/// Everything else. High enough to be invisible in normal use; it only stops
/// a client that has gone wrong, or a crawler.
const generalLimiter = limiter({
  windowMs: 15 * 60 * 1000,
  max: 600,
  code: 'TOO_MANY_REQUESTS',
  message: '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
});

module.exports = {
  createAnalyzeLimiter,
  authLimiter,
  generalLimiter,
  ANALYZE_MAX_GUEST,
  ANALYZE_MAX_USER,
};
