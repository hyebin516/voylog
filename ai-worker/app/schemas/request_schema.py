from typing import List, Literal, Optional

from pydantic import BaseModel


class TranscriptRequest(BaseModel):
    youtubeUrl: str


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
