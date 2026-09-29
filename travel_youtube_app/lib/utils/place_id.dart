final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Whether this place can be bookmarked, put in a folder, or learned from.
///
/// A 뚜벅이 코스 can contain places found live through Kakao's keyword search
/// whose id is `kakao:<id>` rather than a `places.place_id`. The backend now
/// writes those into `places` when a course is saved or published, so most
/// ids that reach a screen are real -- but a course generated and not yet
/// kept still carries Kakao ids, and the bookmark API rejects anything that
/// isn't a UUID. Showing a bookmark button that can only fail is worse than
/// showing none.
bool isBookmarkablePlaceId(String? placeId) =>
    placeId != null && _uuid.hasMatch(placeId);
