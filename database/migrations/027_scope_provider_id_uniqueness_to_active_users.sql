-- Withdrawal is a soft delete, so a withdrawn account's row stays in the
-- table. users.email and users.nickname are already unique only among
-- active rows (uq_users_email, uq_users_nickname), which is what lets a
-- withdrawn user sign up again with the same email/nickname -- but
-- provider_id kept the plain table-level UNIQUE from 001, which does not
-- look at deleted_at. Signing up again after withdrawing therefore failed
-- on users_provider_id_key (23505): the Kakao member number, and for email
-- accounts the email address (createEmailUser stores it as provider_id).
--
-- Only withdrawn rows are affected. Two active accounts still can't share a
-- provider_id, and logging out -- which deletes nothing -- is unchanged.
ALTER TABLE users DROP CONSTRAINT users_provider_id_key;

CREATE UNIQUE INDEX uq_users_provider_id ON users (provider_id) WHERE deleted_at IS NULL;
