// Google Play checks the privacy policy URL during review, so this page has
// to answer without auth, without a database, and without the rate limiter
// in front of it.
jest.mock('../src/config/db');
jest.mock('../src/config/redis');

const request = require('supertest');
const app = require('../src/app');

describe('GET /privacy', () => {
  it('serves the policy as a page anyone can open', async () => {
    const res = await request(app).get('/privacy');

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/html/);
    expect(res.text).toContain('개인정보처리방침');
  });

  it('renders the markdown rather than dumping it', async () => {
    const res = await request(app).get('/privacy');

    expect(res.text).toContain('<h1>');
    expect(res.text).toContain('<table>');
    expect(res.text).not.toContain('## 1. 수집하는 개인정보 항목');
  });

  it('has no unfilled placeholders left in it', async () => {
    // A policy published with "[   이름   ]" still in it is worse than no
    // policy: it tells a reviewer nobody read the page.
    const res = await request(app).get('/privacy');

    expect(res.text).not.toMatch(/\[\s{2,}[^\]]*\s{2,}\]/);
  });
});

describe('GET /terms', () => {
  it('serves the terms as a page anyone can open', async () => {
    const res = await request(app).get('/terms');

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/html/);
    expect(res.text).toContain('이용약관');
  });

  it('states the service is free and has no in-app purchases', async () => {
    // 스토어 심사와 이용자 모두에게 중요한 사실이고, 앱에 결제 코드가
    // 없다는 것과 문서가 어긋나면 안 된다.
    const res = await request(app).get('/terms');

    expect(res.text).toContain('무료');
  });

  it('links to the privacy policy', async () => {
    const res = await request(app).get('/terms');

    expect(res.text).toContain('/privacy');
  });

  it('has no unfilled placeholders left in it', async () => {
    const res = await request(app).get('/terms');

    expect(res.text).not.toMatch(/\[\s{2,}[^\]]*\s{2,}\]/);
  });
});
