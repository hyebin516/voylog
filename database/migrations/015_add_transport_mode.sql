ALTER TABLE itineraries
    ADD COLUMN transport_mode VARCHAR(20) NOT NULL DEFAULT 'car'
        CHECK (transport_mode IN ('car', 'walk'));
