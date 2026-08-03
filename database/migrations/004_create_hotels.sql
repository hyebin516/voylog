CREATE TABLE hotels (
    hotel_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users (user_id),
    name       VARCHAR(300) NOT NULL,
    address    TEXT NOT NULL,
    latitude   DECIMAL(10, 7) NOT NULL,
    longitude  DECIMAL(10, 7) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_hotels_user_id ON hotels (user_id);
