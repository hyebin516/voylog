-- FR-12 push notifications: the only genuinely asynchronous job in the app
-- is the background screen-text enrichment of a video (2-3 minutes), which
-- finishes long after the user has moved on -- so that is what gets pushed
-- ("장소 N곳을 더 찾았어요"), gated by notification_settings.
--
-- device_tokens: one row per device (FCM registration token). A token moves
-- to whichever user last logged in on that device, so the row is keyed by
-- the token, not the user.
CREATE TABLE device_tokens (
    token        TEXT PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users (user_id),
    platform     VARCHAR(10) NOT NULL CHECK (platform IN ('android', 'ios')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_device_tokens_user_id ON device_tokens (user_id);

-- video_analysis_watchers: who asked for this video's analysis and should
-- hear when the background pass adds to it. POST /videos/analyze needs no
-- login, so this row only exists when the request carried a JWT.
CREATE TABLE video_analysis_watchers (
    user_id      UUID NOT NULL REFERENCES users (user_id),
    video_id     UUID NOT NULL REFERENCES videos (video_id),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, video_id)
);

CREATE INDEX idx_video_analysis_watchers_video_id ON video_analysis_watchers (video_id);
