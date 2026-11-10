-- Google Play's user-generated content policy requires an in-app way to
-- report objectionable content. FR-21's public feed shows titles written by
-- other users, so the feed needs one.
--
-- This is a separate table rather than a support_inquiries category because
-- that table's `email` is NOT NULL -- a Kakao account without the email
-- consent item has no address, and such a user must still be able to report.
CREATE TABLE content_reports (
    report_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Reporting requires a login: an anonymous report cannot be followed up
    -- and invites abuse of the reporting itself.
    reporter_user_id UUID NOT NULL REFERENCES users (user_id),
    shared_route_id  UUID NOT NULL REFERENCES shared_routes (shared_route_id),
    reason           VARCHAR(20) NOT NULL
                     CHECK (reason IN ('spam', 'offensive', 'sexual', 'illegal', 'copyright', 'other')),
    -- Free text the reporter may add. Optional: picking a reason is enough.
    detail           TEXT,
    -- Set when the report has been dealt with. Left NULL otherwise; there is
    -- no admin console, so this is updated by hand like support_inquiries.
    resolved_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at       TIMESTAMPTZ
);

-- One report per user per route: pressing 신고 twice is not two reports, and
-- this is what lets the API answer "already reported" without a scan.
CREATE UNIQUE INDEX content_reports_reporter_route_key
    ON content_reports (reporter_user_id, shared_route_id)
 WHERE deleted_at IS NULL;

CREATE INDEX content_reports_shared_route_id_idx ON content_reports (shared_route_id);
