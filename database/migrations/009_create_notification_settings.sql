CREATE TABLE notification_settings (
    user_id           UUID PRIMARY KEY REFERENCES users (user_id),
    trip_alerts       BOOLEAN NOT NULL DEFAULT true,
    service_alerts    BOOLEAN NOT NULL DEFAULT true,
    marketing_alerts  BOOLEAN NOT NULL DEFAULT false,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
