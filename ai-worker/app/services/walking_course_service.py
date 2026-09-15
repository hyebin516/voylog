import random
import re
from typing import List, Optional

from app.constants.tag_catalog import WALKING_COURSE_MOOD_TAG_MAP
from app.schemas.request_schema import (
    HotelInput,
    NearbyScoreRequest,
    PlaceInput,
    RouteOptimizationRequest,
    WalkingCourseRequest,
)
from app.schemas.response_schema import NearbyRecommendation, WalkingCourseResponse
from app.services import kakao_places_service, nearby_recommendation_service, route_optimization_service
from app.utils.distance import haversine_distance_m

MIN_COURSE_PLACES = 2
MAX_COURSE_PLACES = 10
TARGET_COURSE_PLACES = 6

# Sentinel hotelId for the synthetic region-center anchor used when the
# user didn't pick a real hotel. It's never a real hotels.hotel_id, and it
# travels in the saved route_data snapshot, so the frontend uses it to tell
# "no hotel was chosen" apart from a genuine start/end hotel.
VIRTUAL_REGION_ANCHOR_ID = "region-center"

# Legs longer than this aren't "walkable" for the purposes of clustering --
# a candidate is only added to the course if it's within this distance of
# at least one place already selected, so the final course can't sprawl
# across a whole city even if a far-away candidate scores well on its own.
MAX_WALK_LEG_M = 1200

# ~4km/h average walking pace, matching route_optimization_service's own
# Haversine fallback speed for the "walk" transport mode.
WALKING_SPEED_M_PER_MIN = 4000 / 60

# Roughly how long a visitor actually spends at a stop, by category. The
# course's duration is dominated by this, not by walking: ten stops 150m
# apart is ~20 minutes of walking but a genuine half-day outing. Without
# it a "반나절" course reported ~20분, which is why these exist.
_DWELL_MINUTES_BY_CATEGORY = {
    "cafe": 40,
    "bakery": 20,
    "restaurant": 60,
    "dessert": 30,
    "bar": 60,
    "museum": 60,
    "gallery": 45,
    "attraction": 40,
    "shopping": 40,
    "beach": 45,
    "night_view": 30,
}
_DEFAULT_DWELL_MINUTES = 30


def _dwell_minutes(category: Optional[str]) -> int:
    return _DWELL_MINUTES_BY_CATEGORY.get(category or "", _DEFAULT_DWELL_MINUTES)


# Kakao's cafe listings vastly outnumber everything else nearby, so without
# a cap a "course" turns into a cafe crawl. Bakeries/dessert shops count
# against the same quota because they read the same way to a user.
_CAFE_LIKE_CATEGORIES = {"cafe", "bakery", "dessert"}
MAX_CAFE_LIKE_STOPS = 2

# Things to actually do, which is what a walking course is for. These get a
# score nudge so they win ties against the sea of nearby cafes.
_PLAY_CATEGORIES = {"attraction", "museum", "gallery", "shopping"}
PLAY_CATEGORY_BONUS = 0.15

# A place found by the chosen mood's own keyword search. This has to beat
# PLAY_CATEGORY_BONUS: nearby candidates' base scores differ by only a few
# hundredths (they're mostly distance), so a play bonus alone put the same
# handful of attractions on top for every mood -- "조용한" and "활기찬"
# returned identical courses. Mood-matched play places still rank highest.
MOOD_MATCH_BONUS = 0.3

# Random spread added to each candidate's sort key so near-equal places
# trade positions between runs. Without it the order is fixed by distance
# and "다시 생성" keeps returning the same stops; it's small enough that the
# mood and play tiers above still decide which kinds of places win.
SCORE_JITTER = 0.1

# Places from the course the user is regenerating away from. A penalty
# rather than a hard exclusion, so a sparse area can still produce a course.
AVOID_PENALTY = 0.5

# Two stops this close are the same spot on a walk -- often two listings in
# one building with identical coordinates, which also stacked their map pins
# so one was invisible.
MIN_STOP_SEPARATION_M = 15


def _preference_sort_key(
    recommendation: NearbyRecommendation,
    mood_place_ids: frozenset = frozenset(),
    avoid_place_ids: frozenset = frozenset(),
    jitter: float = 0.0,
) -> float:
    key = recommendation.score + jitter
    if (recommendation.category or "") in _PLAY_CATEGORIES:
        key += PLAY_CATEGORY_BONUS
    if recommendation.placeId in mood_place_ids:
        key += MOOD_MATCH_BONUS
    if recommendation.placeId in avoid_place_ids:
        key -= AVOID_PENALTY
    return key


# FR-17 "걷는 시간" chip -> (how many stops to target, how much total time
# the outing should take). The budget covers walking between stops *and*
# time spent at each one, which is what the label means to a user --
# budgeting on walking distance alone let a "반나절" course come back as 20
# minutes. Unselected (None) keeps the unfiltered behavior: a fixed 6-stop
# target with no time cap.
# Stop counts are capped to what the time budget can actually fit at the
# dwell estimates above (~30min/stop), so the two can't contradict each
# other -- 4 stops never fit in an hour.
_DURATION_PROFILES = {
    "1시간 이내": {"targetPlaces": 2, "maxTotalMinutes": 75},
    "2~3시간": {"targetPlaces": 4, "maxTotalMinutes": 180},
    # A full day out: ~8 hours of walking plus time at each stop, which at
    # these dwell estimates fills the 10-stop ceiling.
    "반나절": {"targetPlaces": MAX_COURSE_PLACES, "maxTotalMinutes": 480},
}


def _dedupe_by_place_id(candidates):
    """The category and mood searches overlap, and a bookmarked place can
    also come back from Kakao -- without this the same place could be
    picked twice into one course."""
    seen = set()
    unique = []
    for candidate in candidates:
        if candidate.placeId in seen:
            continue
        seen.add(candidate.placeId)
        unique.append(candidate)
    return unique


# Two listings with the same normalized name this close are one place seen
# by two sources (Kakao's listing and a 상가정보/TourAPI row). A shop's two
# points differ by meters, but a large site's don't: Kakao and TourAPI put
# 경복궁 at different spots on the grounds, and at 50m it showed up twice in
# one course. Names carry the branch ("스타벅스 판교점"), so two genuinely
# different places sharing a full name this close together are rare.
SAME_PLACE_MAX_DISTANCE_M = 300


def _normalized_name(name: str) -> str:
    return re.sub(r"[^0-9a-z가-힣]", "", (name or "").lower())


def _dedupe_same_place(candidates):
    """Keeps the first of each real-world place across sources. Callers order
    candidates by preference (bookmarked, stored, then Kakao), so the kept
    copy is the one carrying the most context. Without this a course could
    visit the same cafe twice under two ids."""
    kept = []
    for candidate in candidates:
        name = _normalized_name(candidate.name)
        is_duplicate = name and any(
            _normalized_name(other.name) == name
            and haversine_distance_m(candidate.latitude, candidate.longitude, other.latitude, other.longitude)
            <= SAME_PLACE_MAX_DISTANCE_M
            for other in kept
        )
        if not is_duplicate:
            kept.append(candidate)
    return kept


# How many of the top-scored candidates the seed is drawn from. Strictly
# taking the single best one made every run in a region produce the exact
# same course; drawing from a small high-scoring pool keeps quality while
# letting "다시 생성" actually generate something different.
SEED_POOL_SIZE = 8


def _brand_key(name: str) -> str:
    """The name without a trailing branch token ("한복남 경복궁점" -> "한복남").
    Only a last word ending in 점 counts as a branch -- a short final word
    is otherwise often part of the real name ("강릉의 밤")."""
    tokens = (name or "").split()
    if len(tokens) >= 2 and len(tokens[-1]) >= 2 and tokens[-1].endswith("점"):
        tokens = tokens[:-1]
    return _normalized_name(" ".join(tokens))


def _same_brand_as_selected(candidate: NearbyRecommendation, selected: List[NearbyRecommendation]) -> bool:
    """Two branches of one chain in a single walk (한복남 프리미엄점 and
    한복남 경복궁점) read as the same stop twice. Candidates are visited best
    first, so whichever branch ranks higher is the one kept."""
    brand = _brand_key(candidate.name)
    return bool(brand) and any(_brand_key(s.name) == brand for s in selected)


def _too_close_to_selected(candidate: NearbyRecommendation, selected: List[NearbyRecommendation]) -> bool:
    return any(
        haversine_distance_m(candidate.latitude, candidate.longitude, s.latitude, s.longitude) < MIN_STOP_SEPARATION_M
        for s in selected
    )


def _select_walkable_cluster(
    scored: List[NearbyRecommendation],
    target_places: int = TARGET_COURSE_PLACES,
    max_total_minutes: Optional[float] = None,
    rng: Optional[random.Random] = None,
    mood_place_ids: frozenset = frozenset(),
    avoid_place_ids: frozenset = frozenset(),
) -> List[NearbyRecommendation]:
    """Greedily builds a mutually-walkable cluster from candidates already
    sorted by score (descending): a seed is drawn from the top-scoring
    candidates, and each subsequent candidate is only added if it's within
    MAX_WALK_LEG_M of at least one place already in the cluster -- and, when
    a time budget is given, only if adding it doesn't push the outing's
    estimated total (walking between stops plus time spent at each one)
    past that budget. This is what keeps the generated course realistically
    walkable, rather than just computing a (possibly huge) walking time
    after the fact.

    The seed is randomized within SEED_POOL_SIZE because seeding strictly
    on the single top-scored place made every run in a region return the
    same course -- the cluster is built around the seed, so varying it
    varies the whole course. Pass `rng` to make the choice deterministic.
    """
    selected: List[NearbyRecommendation] = []
    accumulated_minutes = 0.0
    cafe_like_count = 0
    chooser = rng or random

    sort_keys = {
        c.placeId: _preference_sort_key(
            c,
            mood_place_ids=mood_place_ids,
            avoid_place_ids=avoid_place_ids,
            jitter=chooser.uniform(0, SCORE_JITTER) if SCORE_JITTER else 0.0,
        )
        for c in scored
    }
    ordered = sorted(scored, key=lambda c: sort_keys[c.placeId], reverse=True)
    if ordered:
        seed_index = chooser.randrange(min(SEED_POOL_SIZE, len(ordered)))
        ordered.insert(0, ordered.pop(seed_index))

    for candidate in ordered:
        if len(selected) >= target_places:
            break

        is_cafe_like = (candidate.category or "") in _CAFE_LIKE_CATEGORIES
        if is_cafe_like and cafe_like_count >= MAX_CAFE_LIKE_STOPS:
            continue

        if _too_close_to_selected(candidate, selected) or _same_brand_as_selected(candidate, selected):
            continue

        if not selected:
            selected.append(candidate)
            accumulated_minutes += _dwell_minutes(candidate.category)
            if is_cafe_like:
                cafe_like_count += 1
            continue

        nearest_leg_m = min(
            haversine_distance_m(candidate.latitude, candidate.longitude, s.latitude, s.longitude) for s in selected
        )
        if nearest_leg_m > MAX_WALK_LEG_M:
            continue

        added_minutes = nearest_leg_m / WALKING_SPEED_M_PER_MIN + _dwell_minutes(candidate.category)
        if max_total_minutes is not None and accumulated_minutes + added_minutes > max_total_minutes:
            continue

        accumulated_minutes += added_minutes
        selected.append(candidate)
        if is_cafe_like:
            cafe_like_count += 1

    # A budget tight enough to fit fewer than two stops (two 60-minute
    # restaurants against a 75-minute budget) would otherwise return no
    # course at all. One stop isn't a course, so top up with the shortest
    # walkable options rather than giving up -- overshooting the budget a
    # little beats handing back nothing.
    if len(selected) < MIN_COURSE_PLACES:
        _top_up_to_minimum(selected, ordered)

    return selected


def _top_up_to_minimum(selected: List[NearbyRecommendation], ordered: List[NearbyRecommendation]) -> None:
    chosen_ids = {s.placeId for s in selected}
    remaining = [c for c in ordered if c.placeId not in chosen_ids]
    # Shortest visits first, so the overshoot stays as small as possible.
    remaining.sort(key=lambda c: _dwell_minutes(c.category))

    for candidate in remaining:
        if len(selected) >= MIN_COURSE_PLACES:
            return
        if not selected:
            selected.append(candidate)
            continue
        if _too_close_to_selected(candidate, selected) or _same_brand_as_selected(candidate, selected):
            continue

        nearest_leg_m = min(
            haversine_distance_m(candidate.latitude, candidate.longitude, s.latitude, s.longitude) for s in selected
        )
        if nearest_leg_m > MAX_WALK_LEG_M:
            continue
        selected.append(candidate)


async def generate_walking_course(request: WalkingCourseRequest) -> WalkingCourseResponse:
    kakao_candidates = await kakao_places_service.search_nearby_by_category(
        request.centerLatitude, request.centerLongitude, request.radiusMeters
    )

    # Mood-specific listings, so a different mood actually competes with a
    # different set of places rather than re-ranking the same three
    # category searches (which is why every mood used to return the same
    # course).
    mood_place_ids: frozenset = frozenset()
    if request.mood:
        mood_candidates = await kakao_places_service.search_nearby_by_mood(
            request.centerLatitude, request.centerLongitude, request.radiusMeters, request.mood
        )
        mood_place_ids = frozenset(c.placeId for c in mood_candidates)
        kakao_candidates += mood_candidates

    all_candidates = _dedupe_same_place(
        _dedupe_by_place_id(list(request.bookmarkCandidates) + list(request.placeCandidates) + kakao_candidates)
    )

    if not all_candidates:
        return WalkingCourseResponse(course=None, recommendations=[])

    effective_tag_scores = dict(request.userTagScores)
    mood_tag = WALKING_COURSE_MOOD_TAG_MAP.get(request.mood) if request.mood else None
    if mood_tag:
        # A deliberate, explicit mood pick outweighs whatever the user's
        # passively-learned preference score for this tag happens to be --
        # clamped to 2.0 to match the [-2, 2] range the rest of the app
        # uses for tag_scores.
        effective_tag_scores[mood_tag] = max(effective_tag_scores.get(mood_tag, 0.0), 2.0)
        # Stored places whose own classification carries the mood (a palace
        # is 전통적인 분위기, a market 활기찬 분위기) match it as much as a
        # Kakao keyword hit does, so they get the same bonus -- play places
        # only. 생맥주집 are tagged 활기찬 too, and with the bonus a daytime
        # "활기찬" walk became four bars in a row.
        mood_place_ids = mood_place_ids | frozenset(
            c.placeId
            for c in all_candidates
            if (c.category or "") in _PLAY_CATEGORIES and any(tag.code == mood_tag for tag in c.tags)
        )

    scored = nearby_recommendation_service.score_nearby(
        NearbyScoreRequest(
            latitude=request.centerLatitude,
            longitude=request.centerLongitude,
            localTime=request.localTime,
            radiusMeters=request.radiusMeters,
            limit=len(all_candidates),
            candidates=all_candidates,
            userEmbedding=request.userEmbedding,
            userTagScores=effective_tag_scores,
        )
    ).recommendations

    duration_profile = _DURATION_PROFILES.get(request.walkDuration) if request.walkDuration else None
    selected = _select_walkable_cluster(
        scored,
        target_places=duration_profile["targetPlaces"] if duration_profile else TARGET_COURSE_PLACES,
        max_total_minutes=duration_profile["maxTotalMinutes"] if duration_profile else None,
        mood_place_ids=mood_place_ids,
        avoid_place_ids=frozenset(request.avoidPlaceIds),
    )
    if len(selected) < MIN_COURSE_PLACES:
        return WalkingCourseResponse(course=None, recommendations=selected)

    # When the user picked a start point the course begins and ends there;
    # otherwise it falls back to the region's center. Neither is a real
    # hotel, but optimize_route (shared with FR-07 trip routes) models its
    # endpoints as hotels, so the point is wrapped in HotelInput with a
    # sentinel id that the frontend uses to tell the two cases apart.
    if request.startPoint:
        center_point = HotelInput(
            hotelId=request.startPoint.pointId,
            name=request.startPoint.name,
            latitude=request.startPoint.latitude,
            longitude=request.startPoint.longitude,
        )
    else:
        center_point = HotelInput(
            hotelId=VIRTUAL_REGION_ANCHOR_ID,
            name=request.regionName,
            latitude=request.centerLatitude,
            longitude=request.centerLongitude,
        )
    course = await route_optimization_service.optimize_route(
        RouteOptimizationRequest(
            startHotel=center_point,
            endHotel=center_point,
            places=[PlaceInput(placeId=c.placeId, name=c.name, latitude=c.latitude, longitude=c.longitude) for c in selected],
            routeType="roundTrip",
            optimizationPriority="duration",
            transportMode="walk",
        )
    )

    # optimize_route only knows about travel time between points. For a
    # walking course the number the user reads as "코스 시간" is the whole
    # outing, so the time spent at each stop is added here -- otherwise a
    # 10-stop 반나절 course reports the ~20 minutes of walking between
    # them. Trip itineraries (FR-07) keep optimize_route's travel-only
    # total; this adjustment is specific to FR-17 courses.
    dwell_sec = sum(_dwell_minutes(c.category) for c in selected) * 60
    course.totalDurationSec = (course.totalDurationSec or 0) + dwell_sec

    return WalkingCourseResponse(course=course, recommendations=selected)
