// `POST /videos/analyze` takes no login and spends money on every call, so
// the limit guarding it is worth a test: a limiter that silently stops
// counting looks exactly like one that is working.
jest.mock('../../src/config/db');
jest.mock('../../src/config/redis');

const request = require('supertest');
const app = require('../../src/app');

describe('POST /api/v1/videos/analyze rate limit', () => {
  it('rejects with the standard failure envelope once the hourly limit is spent', async () => {
    // Rejected by the validator long before any LLM call, so this costs
    // nothing but still passes through the limiter.
    const send = () => request(app).post('/api/v1/videos/analyze').send({});

    let limited = null;
    for (let i = 0; i < 25; i++) {
      const res = await send();
      if (res.status === 429) {
        limited = res;
        break;
      }
    }

    expect(limited).not.toBeNull();
    expect(limited.body).toEqual({
      success: false,
      error: {
        code: 'TOO_MANY_REQUESTS',
        message: '분석 요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
      },
    });
  });

  it('advertises the limit in the standard headers', async () => {
    const res = await request(app).post('/api/v1/videos/analyze').send({});
    expect(res.headers).toHaveProperty('ratelimit-limit');
  });
});

describe('GET /health', () => {
  it('answers without authentication, outside the API prefix', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});
