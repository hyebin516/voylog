-- Nicknames must now be unique among active accounts (design handoff's
-- signup screen has a "중복확인" duplicate-check button). Scoped to
-- deleted_at IS NULL, same pattern as uq_users_email, so a withdrawn
-- account's old nickname becomes available again.
CREATE UNIQUE INDEX uq_users_nickname ON users (nickname) WHERE deleted_at IS NULL;
