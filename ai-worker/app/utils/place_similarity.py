"""Decides when two place listings are really the same spot.

The candidate pools mix three sources -- stored vlog places, public
datasets (한국관광공사 / 소상공인 상가정보) and live Kakao searches -- and
each lists places its own way. Shared by the walking course (FR-17), which
keeps one stop per spot, and the nearby list (FR-15), which keeps one card
per spot.
"""

import re

from app.utils.distance import haversine_distance_m

# Two listings of one place are at most this far apart. A shop's points
# differ by meters, but a large site's don't: Kakao and TourAPI put 경복궁
# at different spots on the grounds, several hundred meters apart.
SAME_PLACE_MAX_DISTANCE_M = 300

# Name overlap thresholds for names_overlap. A contained name must be 3+
# characters and at least half of the longer name: "케이락" in "케이락볼링장"
# is one place, while "서울숲" in "서울숲아트센터" or "경복궁" in "한복남
# 경복궁점" is a different place named after its neighbor. A shared prefix
# must be 4+ characters and half of the shorter name, so places that merely
# start with the same city ("부산커피박물관" / "부산포민속박물관") stay
# distinct.
MIN_CONTAINED_NAME_CHARS = 3
MIN_OVERLAP_RATIO = 0.5
MIN_SHARED_PREFIX_CHARS = 4


def normalized_name(name: str) -> str:
    return re.sub(r"[^0-9a-z가-힣]", "", (name or "").lower())


def _shared_prefix_length(a: str, b: str) -> int:
    length = 0
    for char_a, char_b in zip(a, b):
        if char_a != char_b:
            break
        length += 1
    return length


def names_overlap(name_a: str, name_b: str) -> bool:
    """One name contains the other ("케이락" / "케이락볼링장"), or both start
    with most of the shorter one ("제주동문시장" / "제주동문공설시장")."""
    a, b = normalized_name(name_a), normalized_name(name_b)
    shorter, longer = sorted((a, b), key=len)
    if (
        len(shorter) >= MIN_CONTAINED_NAME_CHARS
        and shorter in longer
        and len(shorter) >= len(longer) * MIN_OVERLAP_RATIO
    ):
        return True
    prefix = _shared_prefix_length(a, b)
    return prefix >= MIN_SHARED_PREFIX_CHARS and prefix >= len(shorter) * MIN_OVERLAP_RATIO


def is_same_spot(a, b) -> bool:
    """A nearby listing of the same kind with an overlapping name: one bowling
    alley listed as both "케이락" and "케이락볼링장", or one market complex
    listed as 제주동문시장, 제주동문공설시장 and 제주동문수산시장. Requiring the
    same category keeps a cafe inside the market ("동문시장 과일모찌") as its
    own place. `a` and `b` need name, latitude, longitude and category."""
    return (
        (a.category or "other") == (b.category or "other")
        and haversine_distance_m(a.latitude, a.longitude, b.latitude, b.longitude) <= SAME_PLACE_MAX_DISTANCE_M
        and names_overlap(a.name, b.name)
    )


def collapse_same_spots(ranked):
    """Keeps the first listing of each spot from a best-first list."""
    kept = []
    for item in ranked:
        if not any(is_same_spot(item, other) for other in kept):
            kept.append(item)
    return kept
