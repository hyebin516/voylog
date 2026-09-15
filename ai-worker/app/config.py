import os

from dotenv import load_dotenv

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
KAKAO_REST_API_KEY = os.getenv("KAKAO_REST_API_KEY")
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")
AI_WORKER_PORT = int(os.getenv("AI_WORKER_PORT", "8000"))

LLM_TIMEOUT_SECONDS = 30
KAKAO_TIMEOUT_SECONDS = 10
ROUTE_OPTIMIZATION_TIMEOUT_SECONDS = 15
YOUTUBE_TIMEOUT_SECONDS = 10
# Video download + frame sampling for the on-screen-text (OCR) fallback --
# only runs when a video has no official transcript, so this is allowed a
# much longer budget than the normal LLM_TIMEOUT_SECONDS.
FRAME_EXTRACTION_TIMEOUT_SECONDS = 45
# One sampled frame per this many seconds of video (evenly spaced across
# the 5%-95% middle of the video, skipping likely intro/outro cards) --
# short enough to have a real chance of catching a burned-in caption that's
# only on screen for a few seconds, without sampling every single frame.
FRAME_SAMPLING_INTERVAL_SECONDS = 30
# Safety ceiling regardless of interval/duration -- an unusually long video
# (e.g. a 1-2 hour vlog) shouldn't be allowed to balloon into hundreds of
# frames in a single vision LLM call.
FRAME_SAMPLING_MAX_FRAMES = 24

# The background enrichment pass (forceScreenText) isn't waited on by a
# user, so it can afford to look much harder: a place-name overlay is often
# on screen for only a few seconds, and a 30s sampling interval simply
# misses most of them. The frames go to the vision model in batches, so the
# larger count never becomes one oversized request.
ENRICHMENT_FRAME_INTERVAL_SECONDS = 10
ENRICHMENT_MAX_FRAMES = 120
VISION_BATCH_SIZE = 24
