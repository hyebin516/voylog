CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
    user_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider      VARCHAR(20) NOT NULL CHECK (provider = 'kakao'),
    provider_id   VARCHAR(255) NOT NULL,
    email         VARCHAR(255),
    nickname      VARCHAR(100) NOT NULL,
    profile_image TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ,
    UNIQUE (provider_id)
);

CREATE INDEX idx_users_provider_id ON users (provider_id);
CREATE INDEX idx_users_created_at ON users (created_at);
