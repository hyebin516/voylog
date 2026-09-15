-- FR-15 / FR-17 cold start: places from public datasets.
--
-- Until now every place came from an analyzed video, so "내 주변 추천" had
-- almost nothing to recommend anywhere the team hadn't analyzed a vlog (the
-- nearest place to a test location was 10.7km away). Places are now also
-- bulk-loaded from two public datasets:
--   * tour_api -- 한국관광공사 TourAPI (attractions, culture, shopping, food)
--   * semas    -- 소상공인시장진흥공단 상가(상권)정보 (restaurants, cafes, ...)
--
-- These places have no source video, so video_id becomes nullable. Each one
-- is identified by (source, external_id) so re-running an import updates
-- rows instead of duplicating them.

ALTER TABLE places ALTER COLUMN video_id DROP NOT NULL;

ALTER TABLE places DROP CONSTRAINT IF EXISTS places_source_check;
ALTER TABLE places ADD CONSTRAINT places_source_check CHECK (
    source IN ('transcript', 'on_screen_text', 'hashtags', 'description', 'title', 'tour_api', 'semas')
);

ALTER TABLE places ADD COLUMN IF NOT EXISTS external_id VARCHAR(64);

-- A video-extracted place always has a video; a dataset place always has an
-- external id. Nothing may have neither.
ALTER TABLE places ADD CONSTRAINT places_origin_check CHECK (
    video_id IS NOT NULL OR external_id IS NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_places_source_external_id
    ON places (source, external_id)
    WHERE external_id IS NOT NULL;

-- The nearby query used to scan every place and compute a great-circle
-- distance per row, which was fine for a few dozen video places and is not
-- for hundreds of thousands. It now narrows to a lat/lng bounding box first,
-- which this index serves.
CREATE INDEX IF NOT EXISTS idx_places_lat_lng
    ON places (latitude, longitude)
    WHERE latitude IS NOT NULL AND deleted_at IS NULL;
