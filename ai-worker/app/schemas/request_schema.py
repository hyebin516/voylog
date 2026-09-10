from typing import Dict, List, Literal, Optional

from pydantic import BaseModel

from app.schemas.response_schema import BusinessHours


class TranscriptRequest(BaseModel):
    youtubeUrl: str


class HashtagSearchRequest(BaseModel):
    hashtag: str
    maxResults: int = 20


class VideoSearchRequest(BaseModel):
    query: str
    maxResults: int = 20


class VideoMeta(BaseModel):
    videoId: str
    youtubeUrl: str
    title: Optional[str] = None
    description: Optional[str] = None
    hashtags: List[str] = []


class TranscriptSegment(BaseModel):
    text: str
    timestampSec: int


class PlaceExtractionRequest(BaseModel):
    video: VideoMeta
    transcript: List[TranscriptSegment]
    llmProvider: Literal["auto", "openai", "claude"] = "auto"


class HotelInput(BaseModel):
    hotelId: str
    name: str
    latitude: float
    longitude: float
    address: Optional[str] = None


class PlaceInput(BaseModel):
    placeId: str
    name: str
    latitude: float
    longitude: float


class RouteOptimizationRequest(BaseModel):
    startHotel: HotelInput
    endHotel: HotelInput
    places: List[PlaceInput]
    routeType: Literal["roundTrip", "hotelToHotel"] = "roundTrip"
    optimizationPriority: Literal["duration"] = "duration"
    transportMode: Literal["car", "walk", "transit"] = "car"


class NearbyPlaceTagInput(BaseModel):
    code: str
    confidence: float


class NearbyPlaceCandidate(BaseModel):
    placeId: str
    name: str
    latitude: float
    longitude: float
    category: Optional[str] = None
    businessHours: Optional[BusinessHours] = None
    embedding: Optional[List[float]] = None
    tags: List[NearbyPlaceTagInput] = []


class NearbyScoreRequest(BaseModel):
    latitude: float
    longitude: float
    localTime: str
    radiusMeters: int = 2000
    limit: int = 20
    candidates: List[NearbyPlaceCandidate] = []
    userEmbedding: Optional[List[float]] = None
    userTagScores: Dict[str, float] = {}


class GeocodeRequest(BaseModel):
    query: str


class PlaceSearchRequest(BaseModel):
    query: str
    size: int = 8


class ReverseGeocodeRequest(BaseModel):
    latitude: float
    longitude: float


class WalkingCourseRequest(BaseModel):
    regionName: str
    centerLatitude: float
    centerLongitude: float
    localTime: str
    radiusMeters: int = 3000
    bookmarkCandidates: List[NearbyPlaceCandidate] = []
    userEmbedding: Optional[List[float]] = None
    userTagScores: Dict[str, float] = {}
    # FR-17 mood/duration filters (design handoff chips). Both optional --
    # None means "no preference", matching today's unfiltered behavior.
    mood: Optional[str] = None
    walkDuration: Optional[str] = None


class SimilarTastePlaceCandidate(BaseModel):
    placeId: str
    name: str
    latitude: float
    longitude: float
    category: Optional[str] = None


class SimilarTasteUserInput(BaseModel):
    userId: str
    embedding: Optional[List[float]] = None
    bookmarkedPlaces: List[SimilarTastePlaceCandidate] = []


class SimilarTasteRequest(BaseModel):
    userEmbedding: List[float]
    otherUsers: List[SimilarTasteUserInput] = []
    limit: int = 20


class PlaceSummaryRequest(BaseModel):
    placeName: str
    notes: List[str] = []
    llmProvider: Literal["auto", "openai", "claude"] = "auto"


class EmbeddingRequest(BaseModel):
    text: str


class PreferenceUpdateRequest(BaseModel):
    currentEmbedding: Optional[List[float]] = None
    placeEmbedding: List[float]
    weight: float


class EmbeddingSimilarityTarget(BaseModel):
    key: str
    embedding: List[float]


class EmbeddingSimilarityRequest(BaseModel):
    embeddingA: List[float]
    embeddingsB: List[EmbeddingSimilarityTarget]
