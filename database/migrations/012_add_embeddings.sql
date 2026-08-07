-- Personalized recommendation, phase 3: pretrained-embedding similarity on
-- top of phase 2's distance/time/business-hours scoring. Vectors are stored
-- as JSONB float arrays (no pgvector dependency assumed) and compared with
-- plain cosine similarity in the AI worker.

CREATE TABLE place_embeddings (
    place_id          UUID PRIMARY KEY REFERENCES places (place_id),
    embedding         JSONB NOT NULL,
    model             VARCHAR(100) NOT NULL,
    dimensions        INTEGER NOT NULL,
    source_text_hash  VARCHAR(64) NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One row per user; absence means "no preference set yet" and scoring
-- falls back to phase 2's distance/time/business-hours-only weights.
CREATE TABLE user_preference_embeddings (
    user_id      UUID PRIMARY KEY REFERENCES users (user_id),
    embedding    JSONB NOT NULL,
    source_tags  JSONB NOT NULL,
    source_text  TEXT NOT NULL,
    model        VARCHAR(100) NOT NULL,
    dimensions   INTEGER NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
