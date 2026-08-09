from typing import List, Literal, Optional

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
    userTagCodes: List[str] = []


class EmbeddingRequest(BaseModel):
    text: str
