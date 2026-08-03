# AI WORKER CLAUDE.md

# AI Worker Rules

## Purpose

AI Worker is responsible for all AI-related processing.

AI Worker handles:

- YouTube transcript extraction
- Place extraction
- LLM API calls
- Kakao Maps geocoding
- Route optimization
- Hotel-based round trip planning

Backend must NEVER call OpenAI or Claude directly.

---

# Tech Stack

Language

Python

Framework

FastAPI

LLM Providers

OpenAI

Claude

Map API

Kakao Maps API

Transcript

youtube-transcript-api

---

# Folder Structure

```text
ai-worker/

app/
  main.py
  routers/
    transcript_router.py
    place_router.py
    route_router.py
  services/
    transcript_service.py
    place_extraction_service.py
    llm_service.py
    geocoding_service.py
    route_optimization_service.py
  prompts/
    place_extraction_prompt.py
  schemas/
    request_schema.py
    response_schema.py
  utils/
    exceptions.py
    logger.py
    distance.py

requirements.txt
.env
```

---

# Responsibilities

AI Worker must:

- Receive requests from backend
- Extract transcript
- Call LLM providers
- Parse LLM JSON
- Validate extracted places
- Geocode places using Kakao Maps
- Optimize route using travel time
- Return standardized JSON

AI Worker must not:

- Manage user authentication
- Access PostgreSQL directly
- Save bookmarks
- Issue JWT
- Call frontend directly

---

# API Endpoints

## Transcript

```text
POST /extract-transcript
```

Extract transcript from YouTube video.

## Place Extraction

```text
POST /extract-places
```

Extract places using video metadata and transcript.

## Route Optimization

```text
POST /optimize-route
```

Generate optimized hotel-based route.

---

# LLM Provider Rules

Use both OpenAI and Claude.

Default provider mode:

```text
auto
```

Provider modes:

```text
auto
openai
claude
```

Auto mode flow:

```text
OpenAI
↓
Retry once
↓
Claude
↓
Retry once
↓
Return 503
```

OpenAI is the primary provider.

Claude is the fallback provider.

---

# LLM Rules

LLM must return JSON only.

No markdown.

No explanation.

No natural language response.

No code block.

AI Worker must validate JSON before returning to backend.

If LLM returns invalid JSON:

1. Retry once with same provider
2. Switch provider
3. Return AI_PROVIDER_ERROR if all fail

---

# Place Extraction Input Schema

```json
{
  "video": {
    "videoId": "abc123",
    "youtubeUrl": "https://youtube.com/watch?v=abc123",
    "title": "부산 2박 3일 여행 브이로그",
    "description": "부산 여행 코스",
    "hashtags": ["부산", "해운대", "광안리"]
  },
  "transcript": [
    {
      "text": "드디어 해운대에 도착했습니다.",
      "timestampSec": 120
    }
  ],
  "llmProvider": "auto"
}
```

---

# LLM Place Extraction Output Schema

LLM returns only extracted place candidates.

LLM must not generate coordinates.

```json
{
  "places": [
    {
      "name": "해운대해수욕장",
      "timestampSec": 120,
      "source": "transcript",
      "confidence": 0.96
    }
  ]
}
```

---

# Final Place Output Schema

After Kakao Maps geocoding:

```json
{
  "places": [
    {
      "name": "해운대해수욕장",
      "timestampSec": 120,
      "latitude": 35.158698,
      "longitude": 129.160384,
      "address": "부산광역시 해운대구 우동",
      "source": "transcript",
      "confidence": 0.96
    }
  ]
}
```

---

# Place Extraction Prompt

## System Prompt

You are a travel location extraction assistant.

Your task is to extract real-world travel locations from YouTube travel video information.

You will receive:

- video title
- video description
- hashtags
- transcript with timestamps

Use all available information to identify places that appear in or are strongly related to the video.

---

## Priority

Use information in this order:

1. transcript
2. hashtags
3. description
4. title

If a place appears in transcript, use transcript timestamp.

If a place appears only in metadata, set timestampSec to null.

---

## Extraction Rules

Extract only real-world locations.

Prefer specific searchable place names.

Ignore:

- greetings
- advertisements
- sponsors
- personal opinions
- generic words
- transportation methods
- vague categories

Bad examples:

```text
카페
식당
호텔
시장
거리
여행지
맛집
```

Good examples:

```text
해운대해수욕장
광안리해수욕장
감천문화마을
남산서울타워
성산일출봉
```

---

## Output Rules

Return JSON only.

No markdown.

No explanation.

Use this schema:

```json
{
  "places": [
    {
      "name": "string",
      "timestampSec": 0,
      "source": "transcript",
      "confidence": 0.0
    }
  ]
}
```

Allowed source values:

```text
transcript
hashtags
description
title
```

Confidence must be between 0 and 1.

---

# Geocoding Rules

Use Kakao Maps API.

LLM must never generate coordinates.

Geocoding service receives place name.

Kakao Maps returns:

- latitude
- longitude
- address

If geocoding fails:

```json
{
  "latitude": null,
  "longitude": null,
  "address": null
}
```

Failed geocoding must not stop entire analysis.

---

# Route Optimization Input Schema

```json
{
  "startHotel": {
    "hotelId": "uuid-hotel-1",
    "name": "부산 시그니엘 호텔",
    "latitude": 35.1601,
    "longitude": 129.1635,
    "address": "부산광역시 해운대구 달맞이길"
  },
  "endHotel": {
    "hotelId": "uuid-hotel-2",
    "name": "해운대 그랜드 호텔",
    "latitude": 35.1587,
    "longitude": 129.1604,
    "address": "부산광역시 해운대구 해운대해변로"
  },
  "places": [
    {
      "placeId": "uuid-place-1",
      "name": "해운대해수욕장",
      "latitude": 35.158698,
      "longitude": 129.160384
    }
  ],
  "routeType": "roundTrip",
  "optimizationPriority": "duration"
}
```

If startHotel.hotelId equals endHotel.hotelId, routeType is roundTrip.

If they differ, routeType is hotelToHotel.

routeType is decided by the backend before calling AI Worker. AI Worker does not re-derive it.

---

# Route Optimization Rules

The route always has a fixed start hotel and a fixed end hotel.

Route types:

```text
roundTrip
```

Start Hotel == End Hotel

```text
hotelToHotel
```

Start Hotel != End Hotel

Round trip means:

```text
start hotel → selected places → end hotel (same hotel as start)
```

Hotel-to-hotel means:

```text
start hotel → selected places → end hotel (different hotel)
```

The optimizer must keep both the start hotel and the end hotel fixed as route endpoints.

Only the visiting order of the selected places between them may change.

Minimum selected places:

```text
2
```

Maximum selected places:

```text
10
```

Optimization priority:

```text
duration
```

Use Kakao Maps travel time first.

If Kakao API fails, use Haversine distance fallback.

For 10 or fewer places, use TSP-style route optimization.

Do not optimize routes with more than 10 selected places.

---

# Route Optimization Output Schema

```json
{
  "routeType": "hotelToHotel",
  "optimizationPriority": "duration",
  "startPlace": {
    "type": "hotel",
    "hotelId": "uuid-hotel-1",
    "name": "부산 시그니엘 호텔",
    "latitude": 35.1601,
    "longitude": 129.1635
  },
  "endPlace": {
    "type": "hotel",
    "hotelId": "uuid-hotel-2",
    "name": "해운대 그랜드 호텔",
    "latitude": 35.1587,
    "longitude": 129.1604
  },
  "optimizedRoute": [
    {
      "order": 0,
      "type": "hotel",
      "hotelId": "uuid-hotel-1",
      "name": "부산 시그니엘 호텔"
    },
    {
      "order": 1,
      "type": "place",
      "placeId": "uuid-place-1",
      "name": "해운대해수욕장"
    },
    {
      "order": 2,
      "type": "hotel",
      "hotelId": "uuid-hotel-2",
      "name": "해운대 그랜드 호텔"
    }
  ],
  "totalDistanceM": 15200,
  "totalDurationSec": 3600
}
```

For a roundTrip, startPlace and endPlace reference the same hotelId.

For hotelToHotel, startPlace and endPlace reference different hotels.

---

# Error Rules

Return 422 when transcript is missing.

Return 400 when input schema is invalid.

Return 503 when external API fails.

Return 500 only for unexpected internal errors.

---

# Timeout Rules

LLM request timeout:

```text
30 seconds
```

Kakao Maps request timeout:

```text
10 seconds
```

Route optimization timeout:

```text
15 seconds
```

---

# Environment Variables

```env
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
KAKAO_REST_API_KEY=
YOUTUBE_API_KEY=
AI_WORKER_PORT=
```

---

# Claude Code Instructions

When generating AI Worker code:

- Use FastAPI routers.
- Use Pydantic schemas.
- Keep prompts in prompts/.
- Keep LLM logic in llm_service.py.
- Keep Kakao logic in geocoding_service.py.
- Never hardcode API keys.
- Always validate LLM JSON.
- Always handle provider fallback.
- Always return JSON.
- Never return markdown.
- Never let LLM create coordinates.
- Always prefer Kakao Maps for location data.
- Always enforce 2 to 10 selected places.
- Always keep both the start hotel and the end hotel fixed as route endpoints.
- Default to roundTrip only when start hotel and end hotel are the same; otherwise use hotelToHotel.
