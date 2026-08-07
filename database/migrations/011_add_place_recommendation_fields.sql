-- Personalized nearby recommendation, phase 2 (distance/time/business-hours
-- based, no embeddings/tags yet -- those land in a later phase on top of
-- these columns).
ALTER TABLE places
    ADD COLUMN category VARCHAR(50),
    ADD COLUMN business_hours JSONB,
    ADD COLUMN business_hours_is_estimated BOOLEAN NOT NULL DEFAULT false;

-- business_hours, when present, is always an LLM best-effort read of the
-- source video's transcript/description -- never an authoritative source
-- (Kakao Local API does not expose real operating hours). Shape:
-- { "mon": {"open": "09:00", "close": "21:00"}, "tue": null, ... }
-- A null day means "not mentioned / unknown", not "closed".

CREATE INDEX idx_places_category ON places (category);
