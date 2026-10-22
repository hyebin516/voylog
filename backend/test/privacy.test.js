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
