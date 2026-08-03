// Route-wiring / middleware-order tests: these never need a real DB or Redis
// connection because every case here is rejected by a validator or the auth
// middleware before it would reach a controller/service.
jest.mock('../src/config/db');
jest.mock('../src/config/redis');

const request = require('supertest');
const app = require('../src/app');

describe('unknown routes', () => {
  it('returns the standard 404 failure envelope', async () => {
    const res = await request(app).get('/api/v1/does-not-exist');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ success: false, error: { code: 'NOT_FOUND', message: 'Route not found' } });
  });
});

describe('POST /api/v1/videos/analyze', () => {
  it('rejects a missing youtubeUrl before reaching the controller', async () => {
    const res = await request(app).post('/api/v1/videos/analyze').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_URL');
  });
});

describe('protected routes require a Bearer token', () => {
  it.each([
    ['POST', '/api/v1/bookmarks'],
    ['GET', '/api/v1/bookmarks'],
    ['DELETE', '/api/v1/bookmarks/5ad1f447-a1e2-46a0-8093-0d007ff3071d'],
    ['POST', '/api/v1/hotels'],
    ['GET', '/api/v1/hotels'],
    ['POST', '/api/v1/itineraries'],
    ['GET', '/api/v1/auth/profile'],
  ])('%s %s returns 401 JWT_INVALID without an Authorization header', async (method, path) => {
    const res = await request(app)[method.toLowerCase()](path);
    expect(res.status).toBe(401);
    expect(res.body).toEqual({
      success: false,
      error: { code: 'JWT_INVALID', message: 'Authorization header is missing or malformed' },
    });
  });
});

describe('POST /api/v1/auth/kakao', () => {
  it('rejects a missing kakaoAccessToken before reaching the controller', async () => {
    const res = await request(app).post('/api/v1/auth/kakao').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
  });
});
