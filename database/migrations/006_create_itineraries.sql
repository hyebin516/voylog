CREATE TABLE itineraries (
    itinerary_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL REFERENCES users (user_id),
    start_hotel_id        UUID NOT NULL REFERENCES hotels (hotel_id),
    end_hotel_id          UUID NOT NULL REFERENCES hotels (hotel_id),
    route_type            VARCHAR(20) NOT NULL DEFAULT 'roundTrip' CHECK (route_type IN ('roundTrip', 'hotelToHotel')),
    optimization_priority VARCHAR(20) NOT NULL DEFAULT 'duration',
    total_distance_m      INTEGER,
    total_duration_sec    INTEGER,
    route_data            JSONB NOT NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at            TIMESTAMPTZ
);

CREATE INDEX idx_itineraries_user_id ON itineraries (user_id);
CREATE INDEX idx_itineraries_start_hotel_id ON itineraries (start_hotel_id);
CREATE INDEX idx_itineraries_end_hotel_id ON itineraries (end_hotel_id);
