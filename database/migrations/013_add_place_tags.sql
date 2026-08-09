-- Personalized recommendation, phase 4: detailed tag matching on top of
-- phase 3's embedding similarity. tags is a JSONB array rather than a
-- normalized tags/place_tags table (MVP decision) -- shape:
-- [{"code": "소금빵", "confidence": 0.95}, ...]. "code" is one of the fixed
-- vocabulary values in ai-worker/app/constants/tag_catalog.py, never
-- an arbitrary/new string, so this stays queryable without a lookup table.
ALTER TABLE places
    ADD COLUMN tags JSONB;
