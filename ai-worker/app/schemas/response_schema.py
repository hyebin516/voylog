from typing import List, Literal, Optional

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


class PlaceCandidate(BaseModel):
    name: str
    timestampSec: Optional[int] = None
    source: Literal["transcript", "hashtags", "description", "title"]
    confidence: float


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


class PlaceExtractionResponse(BaseModel):
    places: List[GeocodedPlace]


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
    startPlace: RoutePoint
    endPlace: RoutePoint
    optimizedRoute: List[RoutePoint]
    totalDistanceM: int
    totalDurationSec: int
