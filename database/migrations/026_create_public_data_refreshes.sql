-- FR-15 / FR-17: monthly refresh of the public-dataset places (migration 025).
--
-- The backend re-imports 한국관광공사 TourAPI and, when a newer
-- 소상공인시장진흥공단 상가(상권)정보 file has been placed in
-- database/seed-data/, that dataset too -- once a month. Each run is
-- recorded here, which is both how the backend knows a month has passed and
-- how it knows which 상가정보 edition is already loaded.

CREATE TABLE IF NOT EXISTS public_data_refreshes (
    refresh_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status            VARCHAR(20) NOT NULL CHECK (status IN ('running', 'succeeded', 'failed')),
    semas_edition     VARCHAR(8),          -- YYYYMMDD from the zip file name, when 상가정보 was imported
    tour_api_written  INTEGER,
    semas_written     INTEGER,
    removed_count     INTEGER,             -- places no longer in the data (closed / delisted)
    error             TEXT,
    started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_public_data_refreshes_started_at ON public_data_refreshes (started_at DESC);

-- The first full import was run by hand (TourAPI nationwide + 상가정보
-- 2026-06 edition, all 17 regions) on 2026-09-15. Recording it keeps the
-- scheduler from starting a second full import the moment it's deployed.
INSERT INTO public_data_refreshes (status, semas_edition, started_at, finished_at)
SELECT 'succeeded', '20260630', '2026-09-15T08:00:00Z', '2026-09-15T08:00:00Z'
WHERE NOT EXISTS (SELECT 1 FROM public_data_refreshes);
