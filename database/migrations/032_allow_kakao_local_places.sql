-- FR-17/FR-21: a 뚜벅이 코스 can include places found live through Kakao's
-- keyword search, which were never in `places` -- their id in the course
-- snapshot is "kakao:<id>", not a UUID. `saved_walking_courses.route_data`
-- and `shared_routes.route_data` are FK-free snapshots so they stored those
-- ids happily, but everything that keys off a real place then failed
-- silently:
--
--   * bookmarking such a place was rejected (`isUuid(placeId)` in
--     bookmark.validator.js), so the bookmark icon in a shared route's
--     detail screen just never filled in, with no message;
--   * liking a shared route skipped those places entirely
--     (shared-route.service.js filters non-UUID ids), so a course made
--     entirely of Kakao places taught the preference model nothing.
--
-- So a Kakao place is written into `places` when a course is kept (saved or
-- published) and the snapshot's id is rewritten to the new UUID. Reusing the
-- `(source, external_id)` unique index the public datasets already use makes
-- that idempotent: saving the same course twice updates one row rather than
-- adding a second copy of the cafe.
ALTER TABLE places DROP CONSTRAINT places_source_check;
ALTER TABLE places ADD CONSTRAINT places_source_check
    CHECK (source IN (
        'transcript', 'on_screen_text', 'hashtags', 'description', 'title',
        'tour_api', 'semas', 'kakao_local'
    ));
