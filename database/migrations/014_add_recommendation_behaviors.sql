-- Personalized recommendation, phase 5: behavior-driven learning on top of
-- the survey-seeded embedding/tags from phase 3-4. Only the minimal
-- recommendation context is stored (no raw lat/lng, no movement history --
-- see CLAUDE.md privacy principles).
CREATE TABLE recommendation_behaviors (
    behavior_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users (user_id),
    place_id         UUID NOT NULL REFERENCES places (place_id),
    action           VARCHAR(30) NOT NULL CHECK (
        action IN ('view_detail', 'map_view', 'share', 'bookmark', 'add_to_itinerary', 'like', 'hide', 'not_interested')
    ),
    screen           VARCHAR(50),
    distance_bucket  VARCHAR(20),
    model_version    VARCHAR(30),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_recommendation_behaviors_user_id ON recommendation_behaviors (user_id);
CREATE INDEX idx_recommendation_behaviors_place_id ON recommendation_behaviors (place_id);
CREATE INDEX idx_recommendation_behaviors_user_place_action ON recommendation_behaviors (user_id, place_id, action);

-- Per-tag learned preference strength, seeded at 1.0 for each tag chosen in
-- the taste survey and nudged up/down by behavior afterward. Nullable: rows
-- created before this migration (or a preference row with only an
-- embedding, no behavior yet) simply have no tag_scores until the first
-- behavior event backfills it.
ALTER TABLE user_preference_embeddings
    ADD COLUMN tag_scores JSONB;
