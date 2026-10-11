FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# opencv-python-headless still links against glib even without the GUI
# parts. ffmpeg is deliberately absent: the frame sampler asks yt-dlp for a
# video-only stream precisely so nothing has to be muxed
# (frame_extraction_service._FORMAT_SELECTOR).
RUN apt-get update \
    && apt-get install -y --no-install-recommends libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copied first so a source change does not reinstall the wheel set, which
# includes opencv and is slow to build.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# yt-dlp writes the sampled video to a temp directory; give the unprivileged
# user somewhere to put it.
RUN useradd --create-home --uid 10001 worker \
    && chown -R worker:worker /app
USER worker

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"

# Bound to every interface so the backend container can reach it. Keep this
# service off the public internet, or set AI_WORKER_TOKEN -- it has no user
# accounts and spends money on every call.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
