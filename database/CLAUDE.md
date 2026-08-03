# DATABASE CLAUDE.md

# Database Rules

## Purpose

The database stores all persistent application data.

Database responsibilities:

- User management
- Video cache
- Place information
- Hotels
- Bookmarks
- Route history

Database never contains business logic.

Business logic belongs in Backend or AI Worker.

---

# Database Engine

Primary Database

PostgreSQL

Cache

Redis

---

# Naming Rules

Tables

snake_case

Columns

snake_case

Primary Keys

{table}_id

Foreign Keys

{referenced_table}_id

Boolean

is_

Examples

is_analyzed

is_deleted

---

# ID Rules

All internal entities use UUID.

Never expose sequential IDs.

---

# Timestamp Rules

Every table must include

created_at

updated_at

Optional

deleted_at

Use TIMESTAMP WITH TIME ZONE.

---

# Tables

users

videos

places

hotels

bookmarks

itineraries

---

# Users Table

Purpose

Store authenticated users.

Columns

user_id

provider

provider_id

email

nickname

profile_image

created_at

updated_at

Rules

provider must be

kakao

email may be null

provider_id must be unique

---

# Videos Table

Purpose

Cache analyzed videos.

Columns

video_id

youtube_url

title

description

thumbnail_url

channel_name

published_at

duration_sec

language

is_analyzed

analysis_version

created_at

updated_at

Rules

youtube_url must be unique

Video cache is reused.

Never analyze the same video twice if cache exists.

---

# Places Table

Purpose

Store extracted places.

Columns

place_id

video_id

name

address

latitude

longitude

timestamp_sec

source

confidence

created_at

updated_at

Rules

Coordinates come ONLY from Kakao Maps.

confidence

0.0 ~ 1.0

source values

transcript

hashtags

description

title

---

# Hotels Table

Purpose

Store user-selected hotels.

Columns

hotel_id

user_id

name

address

latitude

longitude

created_at

updated_at

Rules

Hotels are selected using Kakao Maps.

Hotels are user-specific.

Hotel coordinates are mandatory.

---

# Bookmarks Table

Purpose

Store bookmarked places.

Columns

bookmark_id

user_id

place_id

created_at

Rules

One bookmark per user per place.

UNIQUE

(user_id, place_id)

---

# Itineraries Table

Purpose

Store optimized travel routes.

Columns

itinerary_id

user_id

start_hotel_id

end_hotel_id

route_type

optimization_priority

total_distance_m

total_duration_sec

route_data

created_at

updated_at

Rules

route_data uses JSONB.

start_hotel_id and end_hotel_id both reference hotels.hotel_id.

route_type is derived from whether start_hotel_id equals end_hotel_id.

route_type = roundTrip

↓

start_hotel_id == end_hotel_id

route_type = hotelToHotel

↓

start_hotel_id != end_hotel_id

---

# JSONB Rules

Use JSONB for

optimized route

Example

[
    {
        "order":1,
        "placeId":"uuid"
    }
]

Never store relational data inside JSONB.

---

# Foreign Keys

places.video_id

↓

videos.video_id

bookmarks.user_id

↓

users.user_id

bookmarks.place_id

↓

places.place_id

hotels.user_id

↓

users.user_id

itineraries.user_id

↓

users.user_id

itineraries.start_hotel_id

↓

hotels.hotel_id

itineraries.end_hotel_id

↓

hotels.hotel_id

---

# Delete Rules

Never use hard delete.

Prefer soft delete.

Soft delete column

deleted_at

Exception

Redis cache

---

# Index Rules

Create indexes for

youtube_url

provider_id

video_id

user_id

place_id

hotel_id

start_hotel_id

end_hotel_id

created_at

Composite Index

(user_id, place_id)

(video_id, timestamp_sec)

---

# Constraints

UNIQUE

youtube_url

provider_id

(user_id, place_id)

NOT NULL

user_id

video_id

start_hotel_id

end_hotel_id

place_id

name

latitude

longitude

CHECK

confidence

>=0

<=1

---

# Redis Rules

Purpose

Cache analyzed videos.

Key Format

video:{youtube_video_id}

TTL

7 days

Value

Video analysis response JSON

Redis never stores

Users

Bookmarks

Hotels

Routes

---

# Cache Strategy

Request

↓

Redis

↓

PostgreSQL

↓

AI Worker

↓

Save PostgreSQL

↓

Save Redis

↓

Return Result

---

# Normalization Rules

Use

3NF

Do not duplicate

Users

Hotels

Places

Store references instead.

---

# Migration Rules

Never modify production tables manually.

Always use migrations.

Migration names

001_create_users.sql

002_create_videos.sql

003_create_places.sql

...

---

# Backup Rules

Daily backup

Keep

30 backups

Restore testing monthly.

---

# Security Rules

Never store

OAuth Access Token

JWT

API Keys

Passwords in plain text

---

# Performance Rules

Use pagination.

Avoid SELECT *

Use indexes.

Avoid N+1 queries.

Batch inserts when possible.

---

# Database Transaction Rules

Use transactions for

Bookmark creation

Hotel creation

Itinerary creation

Rollback if any step fails.

---

# Environment Variables

DATABASE_URL

POSTGRES_USER

POSTGRES_PASSWORD

POSTGRES_DB

REDIS_URL

---

# Claude Code Instructions

When generating database code

Always use UUID.

Always create foreign keys.

Always create indexes.

Always use JSONB only when necessary.

Always use migrations.

Always add created_at.

Always add updated_at.

Always validate constraints.

Never duplicate data.

Never store coordinates generated by LLM.

Coordinates must come from Kakao Maps.

Use PostgreSQL best practices.
