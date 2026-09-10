from typing import Dict, List, Literal, Optional

from pydantic import BaseModel


class TranscriptResponse(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    hashtags: List[str] = []
    thumbnailUrl: Optional[str] = None
    channelName: Optional[str] = None
    publishedAt: Optional[str] = None
    durationSec: Optional[int] = None
    language: Optional[str] = None
    segments: List[dict]


class VideoSearchResult(BaseModel):
    videoId: str
    youtubeUrl: str
    title: str
    thumbnailUrl: Optional[str] = None
    channelName: Optional[str] = None
    publishedAt: Optional[str] = None


class HashtagSearchResponse(BaseModel):
    videos: List[VideoSearchResult]


class BusinessHoursDay(BaseModel):
    open: Optional[str] = None
    close: Optional[str] = None


# Keyed by lowercase 3-letter weekday (mon..sun). A missing or null day means
# "not mentioned / unknown" -- never inferred, never treated as "closed".
BusinessHours = Dict[str, Optional[BusinessHoursDay]]


class PlaceTag(BaseModel):
    code: str
    confidence: float


class PlaceCandidate(BaseModel):
    name: str
    timestampSec: Optional[int] = None
    source: Literal["transcript", "on_screen_text", "hashtags", "description", "title"]
    confidence: float
    category: Optional[str] = None
    businessHours: Optional[BusinessHours] = None
    tags: List[PlaceTag] = []
    mentionNote: Optional[str] = None


class LlmPlaceExtractionResult(BaseModel):
    places: List[PlaceCandidate]


class GeocodedPlace(BaseModel):
    name: str
    timestampSec: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address: Optional[str] = None
    source: str
    confidence: float
    category: Optional[str] = None
    businessHours: Optional[BusinessHours] = None
    tags: List[PlaceTag] = []
    mentionNote: Optional[str] = None


class PlaceExtractionResponse(BaseModel):
    places: List[GeocodedPlace]


class ScoreDetails(BaseModel):
    distance: float
    timeOfDay: float
    businessHours: float
    embeddingSimilarity: Optional[float] = None
    tagMatch: Optional[float] = None


class NearbyRecommendation(BaseModel):
    placeId: str
    name: str
    latitude: float
    longitude: float
    distanceMeters: int
    category: Optional[str] = None
    isOpen: Optional[bool] = None
    isOpenEstimated: bool
    score: float
    scoreDetails: ScoreDetails
    matchedTags: List[str] = []
    reason: str


class NearbyScoreResponse(BaseModel):
    recommendations: List[NearbyRecommendation]


class GeocodeResponse(BaseModel):
    latitude: float
    longitude: float
    address: Optional[str] = None


class PlaceSearchCandidate(BaseModel):
    placeId: str
    name: str
    address: Optional[str] = None
    latitude: float
    longitude: float


class PlaceSearchResponse(BaseModel):
    candidates: List[PlaceSearchCandidate] = []


class ReverseGeocodeResponse(BaseModel):
    address: Optional[str] = None


class SimilarTasteRecommendation(BaseModel):
    placeId: str
    name: str
    latitude: float
    longitude: float
    category: Optional[str] = None
    score: float
    contributorCount: int
    reason: str


class SimilarTasteResponse(BaseModel):
    recommendations: List[SimilarTasteRecommendation] = []


class EmbeddingResponse(BaseModel):
    embedding: List[float]
    model: str
    dimensions: int


class PreferenceUpdateResponse(BaseModel):
    embedding: List[float]


class EmbeddingSimilarityScore(BaseModel):
    key: str
    score: Optional[float] = None


class EmbeddingSimilarityResponse(BaseModel):
    similarities: List[EmbeddingSimilarityScore]


class RoutePoint(BaseModel):
    order: int
    type: Literal["hotel", "place"]
    hotelId: Optional[str] = None
    placeId: Optional[str] = None
    name: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Distance/duration of the leg arriving at this point from the previous
    # point in the optimized route -- null for the first point (order 0),
    # which has no preceding leg. Lets the UI show real per-stop "도보 N분"
    # rows instead of dividing the aggregate total evenly.
    legDistanceM: Optional[int] = None
    legDurationSec: Optional[int] = None


class RouteOptimizationResponse(BaseModel):
    routeType: str
    optimizationPriority: str
    transportMode: str
    startPlace: RoutePoint
    endPlace: RoutePoint
    optimizedRoute: List[RoutePoint]
    totalDistanceM: int
    totalDurationSec: int


class WalkingCourseResponse(BaseModel):
    # None when fewer than 2 mutually-walkable places could be found nearby
    # (e.g. a region with little bookmark/Kakao coverage) -- not an error.
    course: Optional[RouteOptimizationResponse] = None
    recommendations: List[NearbyRecommendation] = []


class PlaceSummaryResult(BaseModel):
    pros: Optional[str] = None
    cons: Optional[str] = None


class PlaceSummaryResponse(BaseModel):
    pros: Optional[str] = None
    cons: Optional[str] = None
