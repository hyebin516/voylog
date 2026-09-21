require('dotenv').config();

module.exports = {
  port: process.env.PORT || 4000,
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL,
  redisUrl: process.env.REDIS_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  kakaoClientId: process.env.KAKAO_CLIENT_ID,
  kakaoClientSecret: process.env.KAKAO_CLIENT_SECRET,
  aiWorkerUrl: process.env.AI_WORKER_URL,
  smtpHost: process.env.SMTP_HOST,
  smtpPort: Number(process.env.SMTP_PORT) || 587,
  smtpUser: process.env.SMTP_USER,
  smtpPassword: process.env.SMTP_PASSWORD,
  smtpFrom: process.env.SMTP_FROM || 'Voylog <no-reply@voylog.app>',
  tourApiKey: process.env.TOUR_API_KEY,
  // Where FR-13 고객센터 inquiries are forwarded. Same address the app
  // shows on the customer service screen.
  supportEmail: process.env.SUPPORT_EMAIL || 'support@voylog.app',
  // FR-12 push notifications. Without this the app still works; pushes are
  // skipped with a warning (src/services/push.service.js).
  firebaseServiceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
  // Monthly public-dataset refresh (src/jobs/public-data-refresh.job.js).
  // On unless explicitly turned off, e.g. on a second backend instance.
  publicDataRefreshEnabled: process.env.PUBLIC_DATA_REFRESH_ENABLED !== 'false',
};
