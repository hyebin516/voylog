CREATE TABLE videos (
    video_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    youtube_url     TEXT NOT NULL,
    title           VARCHAR(500),
    description     TEXT,
    thumbnail_url   TEXT,
    channel_name    VARCHAR(255),
    published_at    TIMESTAMPTZ,
    duration_sec    INTEGER,
    language        VARCHAR(10),
    is_analyzed     BOOLEAN NOT NULL DEFAULT false,
    analysis_version VARCHAR(20),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ,
    UNIQUE (youtube_url)
);

CREATE INDEX idx_videos_youtube_url ON videos (youtube_url);
CREATE INDEX idx_videos_created_at ON videos (created_at);
