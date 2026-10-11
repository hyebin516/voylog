const rateLimit = require('express-rate-limit');

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

/// The paid path. Generous enough that a person analysing several videos in
/// a row never notices, tight enough that a script cannot run up a bill.
const analyzeLimiter = limiter({
  windowMs: 60 * 60 * 1000,
  max: 20,
  code: 'TOO_MANY_REQUESTS',
  message: '분석 요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
});

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

module.exports = { analyzeLimiter, authLimiter, generalLimiter };
