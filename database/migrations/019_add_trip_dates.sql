ALTER TABLE trips
    ADD COLUMN start_date DATE,
    ADD COLUMN end_date DATE,
    ADD CONSTRAINT chk_trips_date_range CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date);
