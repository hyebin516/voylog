CREATE TABLE places (
    place_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id       UUID NOT NULL REFERENCES videos (video_id),
    name           VARCHAR(300) NOT NULL,
    address        TEXT,
    latitude       DECIMAL(10, 7),
    longitude      DECIMAL(10, 7),
    timestamp_sec  INTEGER,
    source         VARCHAR(20) NOT NULL CHECK (source IN ('transcript', 'hashtags', 'description', 'title')),
    confidence     DECIMAL(3, 2) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at     TIMESTAMPTZ
);

CREATE INDEX idx_places_video_id ON places (video_id);
CREATE INDEX idx_places_video_timestamp ON places (video_id, timestamp_sec);
