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

describe('GET /api/v1/videos/search', () => {
  it('rejects a missing hashtag before reaching the controller', async () => {
    const res = await request(app).get('/api/v1/videos/search');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
  });
});

describe('POST /api/v1/videos/analyze', () => {
  it('rejects a missing youtubeUrl before reaching the controller', async () => {
    const res = await request(app).post('/api/v1/videos/analyze').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_URL');
  });
});

describe('POST /api/v1/videos/recommendations', () => {
  it('rejects a missing regions/themes/duration before reaching the controller', async () => {
    const res = await request(app).post('/api/v1/videos/recommendations').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
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
    ['POST', '/api/v1/trips'],
    ['GET', '/api/v1/trips'],
    ['GET', '/api/v1/trips/5ad1f447-a1e2-46a0-8093-0d007ff3071d'],
    ['PATCH', '/api/v1/trips/5ad1f447-a1e2-46a0-8093-0d007ff3071d'],
    ['DELETE', '/api/v1/trips/5ad1f447-a1e2-46a0-8093-0d007ff3071d'],
    ['POST', '/api/v1/bookmark-folders'],
    ['GET', '/api/v1/bookmark-folders'],
    ['DELETE', '/api/v1/bookmark-folders/5ad1f447-a1e2-46a0-8093-0d007ff3071d'],
    ['GET', '/api/v1/notification-settings'],
    ['PUT', '/api/v1/notification-settings'],
    ['POST', '/api/v1/device-tokens'],
    ['DELETE', '/api/v1/device-tokens/fcm-token'],
    ['PUT', '/api/v1/auth/profile/image'],
    ['DELETE', '/api/v1/auth/profile/image'],
    ['GET', '/api/v1/support-inquiries'],
    ['GET', '/api/v1/taste-preferences'],
    ['PUT', '/api/v1/taste-preferences'],
    ['DELETE', '/api/v1/taste-preferences'],
    ['GET', '/api/v1/auth/profile'],
    ['DELETE', '/api/v1/auth/profile'],
    ['POST', '/api/v1/recommendations/behaviors'],
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

describe('POST /api/v1/recommendations/nearby', () => {
  it('rejects a missing latitude before reaching the controller (no auth required)', async () => {
    const res = await request(app)
      .post('/api/v1/recommendations/nearby')
      .send({ longitude: 127.0, localTime: '2026-08-10T12:00:00+09:00' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
  });
});

describe('POST /api/v1/auth/signup/request-otp', () => {
  it('rejects an invalid email before reaching the controller', async () => {
    const res = await request(app).post('/api/v1/auth/signup/request-otp').send({ email: 'not-an-email' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
  });
});

describe('POST /api/v1/auth/signup/verify-otp', () => {
  it('rejects a missing code before reaching the controller', async () => {
    const res = await request(app).post('/api/v1/auth/signup/verify-otp').send({ email: 'a@b.com' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
  });
});

describe('POST /api/v1/auth/signup', () => {
  it('rejects a password shorter than 8 characters before reaching the controller', async () => {
    const res = await request(app)
      .post('/api/v1/auth/signup')
      .send({ email: 'a@b.com', password: 'short', nickname: 'Nagyeong' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
  });
});

describe('POST /api/v1/auth/login', () => {
  it('rejects a missing password before reaching the controller', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ email: 'a@b.com' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
  });
});
