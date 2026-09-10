import asyncio

import cv2
import numpy as np
import pytest

from app.services import frame_extraction_service


class _FakeYoutubeDL:
    """Stands in for `yt_dlp.YoutubeDL` -- a context manager whose
    `extract_info`/`prepare_filename` this module actually calls."""

    def __init__(self, options):
        self.options = options

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        return False

    def extract_info(self, url, download=True):
        return {"id": "abc123", "ext": "mp4"}

    def prepare_filename(self, info):
        return "/tmp/abc123.mp4"


class _FailingYoutubeDL(_FakeYoutubeDL):
    def extract_info(self, url, download=True):
        raise RuntimeError("video unavailable")


class _FakeCapture:
    """Stands in for `cv2.VideoCapture` -- reports a fixed frame count/fps and
    returns a tiny real frame (so real `cv2.imencode` still works on it)."""

    def __init__(self, total_frames: int, fps: float = 30.0, opened: bool = True):
        self._total_frames = total_frames
        self._fps = fps
        self._opened = opened

    def isOpened(self):
        return self._opened

    def get(self, prop):
        if prop == cv2.CAP_PROP_FRAME_COUNT:
            return self._total_frames
        if prop == cv2.CAP_PROP_FPS:
            return self._fps
        return 0

    def set(self, prop, value):
        pass

    def read(self):
        return True, np.zeros((10, 10, 3), dtype=np.uint8)

    def release(self):
        pass


def test_download_video_returns_the_downloaded_path_on_success(monkeypatch, tmp_path):
    monkeypatch.setattr(frame_extraction_service.yt_dlp, "YoutubeDL", _FakeYoutubeDL)

    path = frame_extraction_service._download_video("https://youtu.be/abc123", str(tmp_path))

    assert path == "/tmp/abc123.mp4"


def test_download_video_returns_none_instead_of_raising_when_yt_dlp_fails(monkeypatch, tmp_path):
    monkeypatch.setattr(frame_extraction_service.yt_dlp, "YoutubeDL", _FailingYoutubeDL)

    path = frame_extraction_service._download_video("https://youtu.be/abc123", str(tmp_path))

    assert path is None


def test_sample_frames_returns_up_to_max_frames_for_a_long_video(monkeypatch):
    # ~55 minutes at 30fps -- far more than enough 30s intervals to hit the cap.
    monkeypatch.setattr(
        frame_extraction_service.cv2, "VideoCapture", lambda path: _FakeCapture(total_frames=100_000, fps=30)
    )

    frames = frame_extraction_service._sample_frames("fake.mp4", interval_seconds=30, max_frames=8)

    assert len(frames) == 8
    assert all(isinstance(f, bytes) for f in frames)


def test_sample_frames_caps_at_the_video_s_actual_frame_count_when_shorter_than_max_frames(monkeypatch):
    # Very low fps means the interval math alone would ask for more samples
    # than the video actually has frames for -- the total-frame-count cap
    # must win over both the interval math and max_frames.
    monkeypatch.setattr(frame_extraction_service.cv2, "VideoCapture", lambda path: _FakeCapture(total_frames=5, fps=0.1))

    frames = frame_extraction_service._sample_frames("fake.mp4", interval_seconds=1, max_frames=8)

    assert len(frames) <= 5


def test_sample_frames_returns_empty_list_when_the_capture_cannot_be_opened(monkeypatch):
    monkeypatch.setattr(
        frame_extraction_service.cv2, "VideoCapture", lambda path: _FakeCapture(total_frames=100, opened=False)
    )

    frames = frame_extraction_service._sample_frames("fake.mp4", max_frames=8)

    assert frames == []


def test_sample_frames_returns_empty_list_when_fps_is_unavailable(monkeypatch):
    monkeypatch.setattr(frame_extraction_service.cv2, "VideoCapture", lambda path: _FakeCapture(total_frames=100, fps=0))

    frames = frame_extraction_service._sample_frames("fake.mp4", max_frames=8)

    assert frames == []


def test_download_and_sample_frames_returns_empty_list_when_download_fails(monkeypatch):
    monkeypatch.setattr(frame_extraction_service, "_download_video", lambda url, dest_dir: None)
    sample_calls = []
    monkeypatch.setattr(
        frame_extraction_service,
        "_sample_frames",
        lambda path, interval_seconds, max_frames: sample_calls.append(path) or [],
    )

    frames = asyncio.run(frame_extraction_service.download_and_sample_frames("https://youtu.be/abc123"))

    assert frames == []
    assert sample_calls == []  # never even tries to sample a video that didn't download


def test_download_and_sample_frames_samples_the_downloaded_file(monkeypatch, tmp_path):
    downloaded_path = tmp_path / "abc123.mp4"
    downloaded_path.write_bytes(b"fake video bytes")

    monkeypatch.setattr(frame_extraction_service, "_download_video", lambda url, dest_dir: str(downloaded_path))
    monkeypatch.setattr(
        frame_extraction_service, "_sample_frames", lambda path, interval_seconds, max_frames: [b"frame1", b"frame2"]
    )

    frames = asyncio.run(
        frame_extraction_service.download_and_sample_frames("https://youtu.be/abc123", max_frames=2)
    )

    assert frames == [b"frame1", b"frame2"]
