-- FR-01 background enrichment.
--
-- A vlog whose auto-generated subtitles mangle proper nouns yields almost
-- no places from text alone; the place names are only readable as on-screen
-- overlays. Reading those means downloading the video, which takes minutes
-- -- far past the 30s budget of the analyze request a user is waiting on.
--
-- So analysis returns the fast text-based result immediately and, when that
-- result looks thin, a background job re-runs extraction with the on-screen
-- text pass and adds whatever it finds. This column tracks that job so the
-- client knows more places may still be coming.
ALTER TABLE videos
    ADD COLUMN IF NOT EXISTS enrichment_status VARCHAR(20)
        CHECK (enrichment_status IN ('pending', 'done', 'failed'));

COMMENT ON COLUMN videos.enrichment_status IS
    'NULL = never needed screen-text enrichment; pending/done/failed = background OCR pass state';
