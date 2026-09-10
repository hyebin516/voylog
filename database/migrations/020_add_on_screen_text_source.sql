ALTER TABLE places
    DROP CONSTRAINT places_source_check;

ALTER TABLE places
    ADD CONSTRAINT places_source_check
        CHECK (source IN ('transcript', 'on_screen_text', 'hashtags', 'description', 'title'));
