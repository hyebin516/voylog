CREATE TABLE shared_routes (
    shared_route_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users (user_id),
    source_type         VARCHAR(20) NOT NULL CHECK (source_type IN ('saved_walking_course', 'itinerary')),
    source_id           UUID NOT NULL,
    title               VARCHAR(100) NOT NULL,
    transport_mode      VARCHAR(20) NOT NULL CHECK (transport_mode IN ('car', 'walk', 'transit')),
    total_distance_m    INTEGER,
    total_duration_sec  INTEGER,
    place_count         INTEGER NOT NULL,
    route_data          JSONB NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_shared_routes_user_id ON shared_routes (user_id);
CREATE INDEX idx_shared_routes_created_at ON shared_routes (created_at DESC);

CREATE TABLE route_likes (
    user_id          UUID NOT NULL REFERENCES users (user_id),
    shared_route_id  UUID NOT NULL REFERENCES shared_routes (shared_route_id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, shared_route_id)
);
