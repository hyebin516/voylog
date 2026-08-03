# BACKEND CLAUDE.md

# Backend Service Rules

## Purpose

The backend is responsible for:

- User authentication
- API endpoints
- Database management
- Redis caching
- Communication with AI Worker
- Returning standardized responses

Backend must NEVER contain AI prompt logic.

---

# Tech Stack

Runtime

Node.js

Framework

Express.js

Database

PostgreSQL

Cache

Redis

Authentication

JWT

OAuth

Kakao OAuth

---

# Architecture

Client

↓

Express Router

↓

Controller

↓

Service

↓

Repository

↓

PostgreSQL

AI Worker communication

↓

FastAPI

---

# Folder Structure

src/

controllers/

services/

repositories/

routes/

middlewares/

models/

config/

utils/

validators/

types/

app.js

server.js

---

# Responsibilities

## Controller

Controller ONLY

- Receive Request
- Validate Input
- Call Service
- Return Response

Controller MUST NOT

- Execute SQL
- Call Redis
- Call OpenAI
- Contain Business Logic

---

## Service

Service handles

- Business Logic
- Cache Logic
- AI Worker Requests
- Authentication Logic
- Route Planning Request

Service MUST NOT

- Return HTTP Responses
- Execute SQL directly

---

## Repository

Repository handles

- PostgreSQL CRUD

Repository MUST

Only communicate with database.

Repository MUST NOT

Contain business logic.

---

# Middleware

Authentication

JWT Verification

Logging

Error Handling

Validation

Rate Limiting

---

# Authentication

OAuth Provider

Kakao

Flow

Flutter

↓

Kakao Login

↓

Backend

↓

Create JWT

↓

Return Token

JWT protects

Bookmarks

Hotels

Route Planner

My Page

---

# API Version

All APIs begin with

/api/v1/

Example

/api/v1/videos/analyze

---

# API Endpoints

Video

POST

/api/v1/videos/analyze

Bookmark

POST

/api/v1/bookmarks

GET

/api/v1/bookmarks

DELETE

/api/v1/bookmarks/:id

Hotel

POST

/api/v1/hotels

GET

/api/v1/hotels

PUT

/api/v1/hotels/:id

DELETE

/api/v1/hotels/:id

Route

POST

/api/v1/itineraries

Auth

POST

/api/v1/auth/kakao

GET

/api/v1/auth/profile

---

# AI Worker Communication

Backend NEVER calls

OpenAI

Claude

Backend ONLY calls

FastAPI

Example

POST

/extract-places

POST

/optimize-route

---

# Cache Rules

Redis First

↓

Database

↓

AI Worker

Cache Key

video:{videoId}

Cache TTL

7 Days

Cache only

Video Analysis

---

# Database Rules

Always use Repository

Never execute SQL inside Service

Use Transactions

When

Bookmark Save

Hotel Save

Route Save

---

# Validation

Validate

YouTube URL

JWT

UUID

Required Fields

Reject invalid requests immediately.

---

# Standard Response

Success

{
    "success": true,
    "data": {}
}

Failure

{
    "success": false,
    "error": {
        "code": "",
        "message": ""
    }
}

---

# HTTP Status

200 OK

201 Created

204 No Content

400 Bad Request

401 Unauthorized

403 Forbidden

404 Not Found

409 Conflict

422 Unprocessable Entity

500 Internal Server Error

503 External API Failure

---

# Error Codes

INVALID_URL

JWT_EXPIRED

JWT_INVALID

BOOKMARK_EXISTS

HOTEL_NOT_FOUND

VIDEO_NOT_FOUND

TRANSCRIPT_NOT_FOUND

AI_TIMEOUT

AI_PROVIDER_ERROR

GEOCODING_FAILED

CACHE_MISS

---

# Logging

Log

Request

Response Time

Error

Redis Cache Hit

Redis Cache Miss

AI Worker Time

Never Log

JWT

OAuth Token

API Keys

Passwords

---

# Environment Variables

PORT

DATABASE_URL

REDIS_URL

JWT_SECRET

KAKAO_CLIENT_ID

KAKAO_CLIENT_SECRET

AI_WORKER_URL

NODE_ENV

---

# Async Rules

Always use

async

await

Never block event loop.

---

# Security

Use HTTPS

Escape SQL

Validate Inputs

Use Parameterized Queries

Never trust client input.

---

# Coding Style

Use camelCase

Use PascalCase for Classes

Keep Functions Small

Prefer Composition

Avoid Duplicate Code

---

# Claude Code Instructions

When generating backend code

Always create

Controller

↓

Service

↓

Repository

Never merge responsibilities.

Always generate validation.

Always generate error handling.

Always generate async code.

Always use Repository Pattern.

Always return standard JSON.

Never call OpenAI directly.

Always communicate with AI Worker.

Never expose secrets.

Generate production-ready code.
