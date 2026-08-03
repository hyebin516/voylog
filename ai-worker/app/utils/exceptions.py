class AiWorkerError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


class TranscriptNotFoundError(AiWorkerError):
    def __init__(self, message: str = "Transcript is not available for this video"):
        super().__init__(422, "TRANSCRIPT_NOT_FOUND", message)


class InvalidRequestError(AiWorkerError):
    def __init__(self, message: str = "Invalid request"):
        super().__init__(400, "INVALID_REQUEST", message)


class AiProviderError(AiWorkerError):
    def __init__(self, message: str = "All LLM providers failed"):
        super().__init__(503, "AI_PROVIDER_ERROR", message)


class GeocodingFailedError(AiWorkerError):
    def __init__(self, message: str = "Kakao geocoding failed"):
        super().__init__(503, "GEOCODING_FAILED", message)


class YoutubeSearchError(AiWorkerError):
    def __init__(self, message: str = "YouTube hashtag search failed"):
        super().__init__(503, "YOUTUBE_SEARCH_FAILED", message)
