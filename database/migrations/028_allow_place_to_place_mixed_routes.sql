-- FR-11: a route built from a bookmark folder has no hotel at either end and
-- is not a loop -- it runs from one bookmarked place to another in the
-- quickest order ('placeToPlace') -- and each leg is walked when that takes at
-- most 15 minutes, otherwise driven ('mixed'). Such a route can be saved to
-- the 내 코스 list and published to the shared feed like any 뚜벅이 코스, so
-- both tables have to accept the new values.
--
-- Trip itineraries (FR-07) are unchanged: they always run between hotels and
-- use the one transport mode the user picked.
ALTER TABLE saved_walking_courses DROP CONSTRAINT saved_walking_courses_route_type_check;
ALTER TABLE saved_walking_courses ADD CONSTRAINT saved_walking_courses_route_type_check
    CHECK (route_type IN ('roundTrip', 'hotelToHotel', 'placeToPlace'));

ALTER TABLE saved_walking_courses DROP CONSTRAINT saved_walking_courses_transport_mode_check;
ALTER TABLE saved_walking_courses ADD CONSTRAINT saved_walking_courses_transport_mode_check
    CHECK (transport_mode IN ('car', 'walk', 'transit', 'mixed'));

ALTER TABLE shared_routes DROP CONSTRAINT shared_routes_transport_mode_check;
ALTER TABLE shared_routes ADD CONSTRAINT shared_routes_transport_mode_check
    CHECK (transport_mode IN ('car', 'walk', 'transit', 'mixed'));
