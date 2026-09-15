import asyncio
import os
import tempfile

import cv2
import yt_dlp

from app.config import (
    FRAME_EXTRACTION_TIMEOUT_SECONDS,
    FRAME_SAMPLING_INTERVAL_SECONDS,
    FRAME_SAMPLING_MAX_FRAMES,
)
from app.utils.logger import logger

# We only need frames, never audio, so request a video-ONLY stream
# explicitly (`bestvideo`, not `best`) -- this avoids needing a system
# `ffmpeg` binary at all. Modern YouTube mostly serves split video-only +
# audio-only DASH streams rather than pre-merged progressive formats, so
# `best` alone frequently has nothing to match and yt-dlp would otherwise
# need ffmpeg to mux a video-only + audio-only pair together.
_FORMAT_SELECTOR = "bestvideo[ext=mp4][height<=480]/bestvideo[ext=mp4]/bestvideo/best"


# The vision call uses low detail, which is rendered at 512px regardless,
# so larger frames only inflate the request (a 480p frame was ~160KB, and
# the enrichment pass sends up to ENRICHMENT_MAX_FRAMES of them).
_MAX_FRAME_WIDTH = 768
_JPEG_QUALITY = 80


def _shrink_for_vision(frame):
    height, width = frame.shape[:2]
    if width <= _MAX_FRAME_WIDTH:
        return frame
    scale = _MAX_FRAME_WIDTH / width
    return cv2.resize(frame, (_MAX_FRAME_WIDTH, int(height * scale)), interpolation=cv2.INTER_AREA)


def _download_video(youtube_url: str, dest_dir: str) -> str | None:
    """Downloads a low-resolution copy of the video into `dest_dir`.
    Returns the local file path, or None if the download failed for any
    reason -- this is a best-effort fallback, never meant to raise."""
    out_template = os.path.join(dest_dir, "%(id)s.%(ext)s")
    options = {
        "format": _FORMAT_SELECTOR,
        "outtmpl": out_template,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "noplaylist": True,
        "socket_timeout": FRAME_EXTRACTION_TIMEOUT_SECONDS,
    }
    try:
        with yt_dlp.YoutubeDL(options) as ydl:
            info = ydl.extract_info(youtube_url, download=True)
            return ydl.prepare_filename(info)
    except Exception as exc:
        logger.warning("Frame extraction: video download failed for %s: %s", youtube_url, exc)
        return None


def _sample_frames(
    video_path: str,
    interval_seconds: float = FRAME_SAMPLING_INTERVAL_SECONDS,
    max_frames: int = FRAME_SAMPLING_MAX_FRAMES,
) -> list[bytes]:
    """Reads JPEG-encoded frames evenly spaced across the video's duration,
    roughly one every `interval_seconds` (capped at `max_frames` regardless
    of how long the video is). A fixed frame *count* regardless of video
    length would badly under-sample a long video -- a burned-in caption is
    only ever on screen for a few seconds, so a 20-minute vlog needs many
    more samples than a 2-minute one to have a real chance of catching one.
    Returns an empty list if the file can't be read at all -- never
    raises."""
    capture = cv2.VideoCapture(video_path)
    try:
        if not capture.isOpened():
            logger.warning("Frame extraction: could not open downloaded video %s", video_path)
            return []

        total_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = capture.get(cv2.CAP_PROP_FPS)
        if total_frames <= 0 or fps <= 0:
            return []

        # Evenly spaced frame indices, skipping the very first/last instants
        # (often black/title cards) by sampling from 5%..95% of the video.
        start, end = int(total_frames * 0.05), int(total_frames * 0.95)
        if end <= start:
            start, end = 0, total_frames - 1
        window_seconds = (end - start) / fps

        count = max(1, round(window_seconds / interval_seconds))
        count = min(count, max_frames, total_frames)
        step = max((end - start) // max(count - 1, 1), 1)

        frames: list[bytes] = []
        for i in range(count):
            frame_index = min(start + i * step, total_frames - 1)
            capture.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
            ok, frame = capture.read()
            if not ok:
                continue
            frame = _shrink_for_vision(frame)
            ok, encoded = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, _JPEG_QUALITY])
            if ok:
                frames.append(encoded.tobytes())
        return frames
    finally:
        capture.release()


async def download_and_sample_frames(
    youtube_url: str,
    interval_seconds: float = FRAME_SAMPLING_INTERVAL_SECONDS,
    max_frames: int = FRAME_SAMPLING_MAX_FRAMES,
) -> list[bytes]:
    """Downloads a low-res copy of the video and samples JPEG frames roughly
    every `interval_seconds` of its duration (capped at `max_frames`), for
    OCR/vision text extraction. This is a best-effort fallback only used
    when a video has no official transcript -- any failure (download,
    decode, etc.) returns an empty list instead of raising, so it never
    breaks the main place extraction flow it's a fallback for."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        video_path = await asyncio.to_thread(_download_video, youtube_url, tmp_dir)
        if not video_path or not os.path.exists(video_path):
            return []
        return await asyncio.to_thread(_sample_frames, video_path, interval_seconds, max_frames)
