ALTER TABLE users
    DROP CONSTRAINT users_provider_check,
    ADD CONSTRAINT users_provider_check CHECK (provider IN ('kakao', 'email')),
    ADD COLUMN password_hash VARCHAR(255);

-- Only email/password accounts have an email that must be unique; Kakao
-- accounts may share a null email or one not verified with Kakao.
CREATE UNIQUE INDEX uq_users_email ON users (email) WHERE email IS NOT NULL AND deleted_at IS NULL;

-- Short-lived signup email verification codes. A row is created on
-- request-otp, marked verified_at on a correct verify-otp call, and consumed
-- (deleted) once POST /auth/signup succeeds.
CREATE TABLE email_otps (
    otp_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) NOT NULL,
    code_hash   VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ,
    attempts    INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_email_otps_email ON email_otps (email);
