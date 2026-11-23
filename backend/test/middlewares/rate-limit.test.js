// `POST /videos/analyze` takes no login and spends money on every call, so
// the limit guarding it is worth a test: a limiter that silently stops
// counting looks exactly like one that is working. The opposite failure is
// just as real -- in a live demo it refused a logged-in user and counted
// free cache hits, until analysis stopped working on the presenter's phone.
jest.mock('../../src/config/db');
jest.mock('../../src/config/redis');
jest.mock('../../src/services/video.service');

const request = require('supertest');
const jwt = require('jsonwebtoken');

const URL_A = 'https://www.youtube.com/watch?v=AAAAAAAAAAA';

/// The limiter keeps its counts in module memory, so each test gets a
/// fresh app -- otherwise one test's requests would eat the next one's
/// allowance.
function freshApp({ isAlreadyAnalyzed = false } = {}) {
  let app;
  let videoService;
  jest.isolateModules(() => {
    videoService = require('../../src/services/video.service');
    videoService.isAlreadyAnalyzed.mockResolvedValue(isAlreadyAnalyzed);
    videoService.analyzeVideo.mockResolvedValue({ videoId: 'v1', places: [] });
    app = require('../../src/app');
  });
  return { app, videoService };
}

function tokenFor(userId) {
  return jwt.sign({ userId }, process.env.JWT_SECRET);
}

async function sendUntilLimited(app, { times, token } = {}) {
  for (let i = 1; i <= times; i++) {
    let req = request(app).post('/api/v1/videos/analyze');
    if (token) req = req.set('Authorization', `Bearer ${token}`);
    const res = await req.send({ youtubeUrl: URL_A });
    if (res.status === 429) return { res, attempt: i };
  }
  return { res: null, attempt: null };
}

describe('POST /api/v1/videos/analyze rate limit', () => {
  it('lets a guest run 20 analyses an hour, then asks them to log in', async () => {
    const { app } = freshApp();

    const { res, attempt } = await sendUntilLimited(app, { times: 25 });

    expect(attempt).toBe(21);
    expect(res.body).toEqual({
      success: false,
      error: {
        code: 'ANALYZE_LIMIT_GUEST',
        message: '로그인하지 않으면 1시간에 20번까지 분석할 수 있어요. 로그인하면 계속 분석할 수 있어요.',
      },
    });
  });

  it('does not count videos that are already analyzed', async () => {
    // Cache hits cost nothing, and the app polls them every 5 seconds while
    // the background pass runs -- counting them spent the whole allowance
    // on one video.
    const { app, videoService } = freshApp({ isAlreadyAnalyzed: true });

    const { res } = await sendUntilLimited(app, { times: 30 });

    expect(res).toBeNull();
    expect(videoService.analyzeVideo).toHaveBeenCalledTimes(30);
  });

  it('counts the request when it cannot tell whether the video is cached', async () => {
    // A failing lookup must not open the paid path.
    const { app, videoService } = freshApp();
    videoService.isAlreadyAnalyzed.mockRejectedValue(new Error('redis down'));

    const { attempt } = await sendUntilLimited(app, { times: 25 });

    expect(attempt).toBe(21);
  });

  it('counts a logged-in user per account, not per IP', async () => {
    // Same IP as an exhausted guest -- the demo case: phone on a hotspot.
    const { app } = freshApp();
    await sendUntilLimited(app, { times: 21 });

    const res = await request(app)
      .post('/api/v1/videos/analyze')
      .set('Authorization', `Bearer ${tokenFor('user-1')}`)
      .send({ youtubeUrl: URL_A });

    expect(res.status).toBe(200);
  });

  it('gives a logged-in user a larger allowance with the generic message', async () => {
    const { app } = freshApp();

    const { res, attempt } = await sendUntilLimited(app, { times: 105, token: tokenFor('user-2') });

    expect(attempt).toBe(101);
    expect(res.body.error.code).toBe('TOO_MANY_REQUESTS');
  });

  it('does not count requests the validator rejects', async () => {
    const { app } = freshApp();
    for (let i = 0; i < 25; i++) {
      await request(app).post('/api/v1/videos/analyze').send({});
    }

    const res = await request(app).post('/api/v1/videos/analyze').send({ youtubeUrl: URL_A });

    expect(res.status).toBe(200);
  });

  it('advertises the limit in the standard headers', async () => {
    const { app } = freshApp();
    const res = await request(app).post('/api/v1/videos/analyze').send({ youtubeUrl: URL_A });
    expect(res.headers).toHaveProperty('ratelimit-limit');
  });
});

describe('GET /health', () => {
  it('answers without authentication, outside the API prefix', async () => {
    const { app } = freshApp();
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});
