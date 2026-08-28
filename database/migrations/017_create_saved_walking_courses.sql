CREATE TABLE saved_walking_courses (
    saved_course_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users (user_id),
    region              VARCHAR(100) NOT NULL,
    route_type          VARCHAR(20) NOT NULL DEFAULT 'roundTrip' CHECK (route_type IN ('roundTrip', 'hotelToHotel')),
    transport_mode      VARCHAR(20) NOT NULL DEFAULT 'walk' CHECK (transport_mode IN ('car', 'walk', 'transit')),
    total_distance_m    INTEGER,
    total_duration_sec  INTEGER,
    route_data          JSONB NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_saved_walking_courses_user_id ON saved_walking_courses (user_id);
