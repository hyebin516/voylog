// Deterministic env vars for tests, independent of the developer's local .env.
// dotenv.config() (called from src/config/env.js) never overwrites values that
// are already set, so setting these here makes tests reproducible in CI too.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-jwt-secret';
process.env.JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1h';
process.env.DATABASE_URL = process.env.DATABASE_URL || 'postgres://test:test@localhost:5432/test';
process.env.REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
process.env.AI_WORKER_URL = process.env.AI_WORKER_URL || 'http://localhost:8000';
