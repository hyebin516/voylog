-- Cross-video place pros/cons summary. mention_note is captured per place
-- row at extraction time (one video's LLM read of what was said about that
-- place, if anything); pros_summary/cons_summary are a cached LLM synthesis
-- across every place row that shares (roughly) the same coordinates --
-- i.e. the same real-world place mentioned in multiple different videos.
-- Denormalized onto the requested place row rather than a separate
-- "canonical place" table (MVP decision, mirrors the tags/business_hours
-- columns already on this table).
ALTER TABLE places
    ADD COLUMN mention_note TEXT,
    ADD COLUMN pros_summary TEXT,
    ADD COLUMN cons_summary TEXT,
    ADD COLUMN summary_source_count INTEGER,
    ADD COLUMN summary_generated_at TIMESTAMPTZ;

-- Cache invalidation reads this: if the live count of distinct videos with
-- a mention_note near this place's coordinates no longer matches
-- summary_source_count, the summary is regenerated.
