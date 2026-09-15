const Redis = require('ioredis');
const env = require('./env');

// The video-analysis cache is explicitly best-effort (see CLAUDE.md's
// caching strategy: Redis -> PostgreSQL -> AI Worker) -- a single failed
// command should surface quickly so video.service.js's try/catch can fall
// through to PostgreSQL, instead of ioredis's default of retrying a command
// up to 20 times before giving up (which made every analyze request hang
// and then 500 whenever Redis was unreachable).
const redis = new Redis(env.redisUrl, { maxRetriesPerRequest: 1 });

// ioredis logs "Unhandled error event" noise to stderr if nothing listens
// for 'error' on the client; the background reconnect loop itself is
// harmless (and expected while Redis is down in local dev), so just
// swallow it here instead of letting it flood the console.
redis.on('error', () => {});

module.exports = redis;
