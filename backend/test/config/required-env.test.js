// The server used to boot with an empty JWT_SECRET and sign tokens nobody
// could verify. These pin the "refuse to start, and say which one" rule.
//
// The env module is mocked rather than the process environment, because
// src/config/env.js calls dotenv.config(), which refills anything deleted
// from process.env straight back out of backend/.env.

const FULL = {
  databaseUrl: 'postgres://u:p@localhost:5432/db',
  jwtSecret: 'secret',
  aiWorkerUrl: 'http://localhost:8000',
  redisUrl: 'redis://localhost:6379',
  firebaseServiceAccountPath: '/tmp/firebase.json',
  smtpHost: 'smtp.example.com',
  kakaoClientId: 'kakao-id',
};

function loadWith(overrides) {
  jest.resetModules();
  jest.doMock('../../src/config/env', () => ({ ...FULL, ...overrides }));
  return require('../../src/config/required-env');
}

const silentLogger = { warn: () => {} };

afterEach(() => {
  jest.resetModules();
  jest.dontMock('../../src/config/env');
});

describe('assertEnv', () => {
  it('passes when everything required is set', () => {
    const { assertEnv } = loadWith({});
    expect(() => assertEnv({ logger: silentLogger })).not.toThrow();
  });

  it('names the missing variable rather than failing later', () => {
    const { assertEnv } = loadWith({ jwtSecret: undefined });
    expect(() => assertEnv({ logger: silentLogger })).toThrow(/JWT_SECRET/);
  });

  it('lists every missing variable at once', () => {
    const { assertEnv } = loadWith({ jwtSecret: undefined, databaseUrl: undefined });
    let message = '';
    try {
      assertEnv({ logger: silentLogger });
    } catch (e) {
      message = e.message;
    }
    expect(message).toMatch(/DATABASE_URL/);
    expect(message).toMatch(/JWT_SECRET/);
  });

  it('warns about an optional variable but still starts', () => {
    const { assertEnv } = loadWith({ redisUrl: undefined });
    const warnings = [];
    expect(() => assertEnv({ logger: { warn: (m) => warnings.push(m) } })).not.toThrow();
    expect(warnings.join(' ')).toMatch(/REDIS_URL/);
  });

  it('says what each missing optional costs, so the gap is not a mystery', () => {
    const { assertEnv } = loadWith({ firebaseServiceAccountPath: undefined });
    const warnings = [];
    assertEnv({ logger: { warn: (m) => warnings.push(m) } });
    expect(warnings.join(' ')).toMatch(/푸시 알림/);
  });
});
