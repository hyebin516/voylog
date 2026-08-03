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
};
