ALTER TABLE itineraries
    DROP CONSTRAINT itineraries_transport_mode_check;

ALTER TABLE itineraries
    ADD CONSTRAINT itineraries_transport_mode_check
        CHECK (transport_mode IN ('car', 'walk', 'transit'));
