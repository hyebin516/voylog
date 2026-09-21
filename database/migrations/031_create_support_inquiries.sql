-- FR-13: the customer service screen only showed an email address, which
-- nobody can act on from inside the app. Inquiries now land in the DB so
-- the user can see their own history even if the mail delivery fails.
CREATE TABLE support_inquiries (
    inquiry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Nullable: the customer service screen is reachable without logging in
    -- (my page shows "비회원으로 둘러보는 중"), and someone who cannot log
    -- in is exactly who needs to ask for help.
    user_id    UUID REFERENCES users (user_id),
    -- Always collected, even for a logged-in user: a Kakao account without
    -- the email consent item has no address to reply to.
    email      VARCHAR(255) NOT NULL,
    category   VARCHAR(20) NOT NULL CHECK (category IN ('analysis', 'route', 'account', 'bug', 'other')),
    message    TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_support_inquiries_user_id ON support_inquiries (user_id);
CREATE INDEX idx_support_inquiries_created_at ON support_inquiries (created_at DESC);
