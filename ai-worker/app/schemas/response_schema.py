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
    source: Literal["transcript", "hashtags", "description", "title"]
    confidence: float
    category: Optional[str] = None
    businessHours: Optional[BusinessHours] = None
    tags: List[PlaceTag] = []


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


class RoutePoint(BaseModel):
    order: int
    type: Literal["hotel", "place"]
    hotelId: Optional[str] = None
    placeId: Optional[str] = None
    name: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


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
