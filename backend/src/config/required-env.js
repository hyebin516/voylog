const env = require('./env');

// Without these the server starts and then fails in ways that look like
// something else: an empty JWT_SECRET signs tokens nobody can verify, a
// missing DATABASE_URL turns every request into a connection error, and a
// missing AI_WORKER_URL makes analysis fail with a generic 500. Better to
// refuse to start and say which one is missing.
const REQUIRED = {
  DATABASE_URL: env.databaseUrl,
  JWT_SECRET: env.jwtSecret,
  AI_WORKER_URL: env.aiWorkerUrl,
};

// Optional, but their absence changes what the app can do, so it is said out
// loud at boot rather than discovered when a user hits the feature.
const OPTIONAL = {
  REDIS_URL: [env.redisUrl, '분석 결과 캐시가 꺼진 채로 동작합니다(매번 DB 조회).'],
  FIREBASE_SERVICE_ACCOUNT_PATH: [env.firebaseServiceAccountPath, '푸시 알림이 전송되지 않습니다.'],
  SMTP_HOST: [env.smtpHost, '이메일 인증코드와 고객센터 메일이 전송되지 않습니다.'],
  KAKAO_CLIENT_ID: [env.kakaoClientId, '카카오 로그인이 동작하지 않습니다.'],
};

function missingRequired() {
  return Object.entries(REQUIRED)
    .filter(([, value]) => !value)
    .map(([name]) => name);
}

function missingOptional() {
  return Object.entries(OPTIONAL)
    .filter(([, [value]]) => !value)
    .map(([name, [, consequence]]) => `${name} — ${consequence}`);
}

/// Throws when something required is missing, warns about the rest.
function assertEnv({ logger = console } = {}) {
  for (const warning of missingOptional()) {
    logger.warn(`[env] ${warning}`);
  }

  const missing = missingRequired();
  if (missing.length > 0) {
    throw new Error(
      `필수 환경변수가 없습니다: ${missing.join(', ')}. backend/.env를 확인하세요.`
    );
  }
}

module.exports = { assertEnv, __testing: { missingRequired, missingOptional } };
