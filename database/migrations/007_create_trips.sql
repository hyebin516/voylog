CREATE TABLE trips (
    trip_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users (user_id),
    name       VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_trips_user_id ON trips (user_id);

-- A trip is made up of per-day itineraries. Each day keeps its own
-- start/end hotel pair (e.g. day 1 hotel A -> hotel B, day 2 hotel B ->
-- hotel B round trip) but reuses the existing single-day hotel-to-hotel
-- optimization untouched.
ALTER TABLE itineraries
    ADD COLUMN trip_id    UUID NOT NULL REFERENCES trips (trip_id),
    ADD COLUMN day_number INTEGER NOT NULL CHECK (day_number > 0);

CREATE INDEX idx_itineraries_trip_id ON itineraries (trip_id);
CREATE UNIQUE INDEX uq_itineraries_trip_day ON itineraries (trip_id, day_number) WHERE deleted_at IS NULL;
