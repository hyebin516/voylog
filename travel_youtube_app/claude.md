# FRONTEND CLAUDE.md

# App Identity

App name: **Voylog**

Android applicationId (target): com.luckyvicky.voylog (see docs/PACKAGE_RENAME_GUIDE.md — not yet applied, current is com.example.travel_youtube_app)

iOS Bundle ID (target): com.luckyvicky.voylog (same guide)

---

# Platform Scope

This project is a Flutter **Android/iOS native app**. It is NOT a Flutter Web app.

Never use:

package:web

dart:js_interop

Any direct browser-only Kakao Maps JavaScript SDK implementation (raw `<script>` tags, `dart:ui_web` platform views, manual JS injection)

Maps are rendered ONLY through `kakao_map_plugin` (a real Flutter plugin backed by `webview_flutter`, encapsulated entirely inside `KakaoMapWidget`). This is allowed because it is a proper cross-platform plugin with Android/iOS support — it is not the same thing as writing our own browser-only code.

Only `android/` and `ios/` platform folders exist. Do not add `web/`, `windows/`, `macos/`, `linux/` folders or dependencies without an explicit request.

---

# Flutter Rules

## Purpose

Frontend is responsible for:

- User Interface
- User Interaction
- State Management
- API Communication
- Local Validation

Frontend must NEVER contain business logic.

Business logic belongs to Backend and AI Worker.

---

# Tech Stack

Framework

Flutter

Language

Dart

State Management

Provider

Networking

Dio

Maps

kakao_map_plugin (native Android/iOS plugin backed by webview_flutter — NOT browser-only dart:js_interop/package:web)

Video

youtube_player_iframe

Storage

flutter_secure_storage

---

# Folder Structure

lib/

main.dart

app/

core/

config/

constants/

models/

services/

repositories/

providers/

screens/

widgets/

routes/

utils/

assets/

---

# Layer Responsibilities

Screens

Display UI

Receive user interaction

Call Provider

Widgets

Reusable UI only

No business logic

Providers

Manage state

Call Repository

Repositories

Call Backend API

Return Model

Services

Low-level API communication

Models

Represent API JSON

---

# Screen List

Splash Screen

Login Screen

Home Screen

Video Analysis Screen

Place Detail Screen

Bookmark Screen

Hotel Search Screen

Route Planner Screen

My Page

Settings Screen

---

# Navigation

Use named routes.

Do not navigate using hardcoded routes.

All routes belong in routes/.

---

# State Management

Provider manages

Loading

Success

Error

Selected Start Hotel

Selected End Hotel

Selected Places

Bookmarks

Current Video

Route Result

Never use global mutable variables.

---

# API Rules

Frontend NEVER calls

OpenAI

Claude

Kakao REST API

Frontend ONLY calls

Backend API

Example

POST

/api/v1/videos/analyze

---

# Dio Rules

Create one Dio instance.

Use interceptor.

Automatically attach JWT.

Handle

401

403

500

503

Globally.

---

# Authentication

Use Kakao Login.

Flow

Splash

↓

Login

↓

Backend

↓

JWT

↓

Secure Storage

↓

Home

JWT stored only in

flutter_secure_storage

Never use SharedPreferences for JWT.

---

# JSON Models

Every API response has

Model

Example

VideoModel

PlaceModel

HotelModel

BookmarkModel

RouteModel

Never use dynamic.

Use strongly typed models.

---

# Home Screen

Contains

YouTube URL Input

Analyze Button

Recent Videos

Search Bar

Loading Indicator

---

# Video Analysis Screen

Display

Embedded YouTube Player

Place Cards

Timestamp Button

Bookmark Button

Map Button

Loading

Error

---

# Place Card

Contains

Place Name

Address

Timestamp

Bookmark Icon

Map Button

---

# Kakao Maps

All map screens use the shared `KakaoMapWidget` (widgets/kakao_map_widget.dart).

Screens never import `kakao_map_plugin` directly — only `KakaoMapWidget` does.

## Platform implementation

kakao_map_plugin renders the Kakao Maps JS SDK inside a native WebView
(webview_flutter) on Android and iOS. This is a real Flutter plugin with
platform channels, not Flutter Web / dart:js_interop.

The Kakao app key (JavaScript key) is injected once at startup via
`MapService.initialize()` in main.dart, which reads `Env.kakaoJavascriptKey`
from the `.env` file (see Environment section).

## Hotel selection (Start/End)

Start/End hotel selection

↓

Drag map to desired location (centered pin overlay)

↓

Enter hotel name

↓

Confirm "이 위치를 호텔로 저장"

↓

User selects Start Hotel

↓

User selects End Hotel

↓

Both hotels saved

↓

Route planner enabled

If Start Hotel and End Hotel are the same, treat as Round Trip.

If they differ, treat as Hotel → Hotel.

Never manually enter coordinates. Location always comes from the map
(dragged center or a marker tap), never a text lat/lng field.

Frontend never calls the Kakao REST API (search, geocoding) directly —
that stays in the AI Worker. Hotel Search Screen picks a location by
moving the map, not by keyword search.

## Testing

Screens never construct `KakaoMapWidget` directly. They accept a
`MapRepository` (repositories/map_repository.dart), defaulting to
`KakaoMapRepository()`. Widget tests inject `FakeMapRepository()`
(test/fakes/fake_map_widget.dart) instead, so the real map SDK never
loads under `flutter test`. Real map behavior (SDK load, markers, drag)
is verified separately via `integration_test/kakao_map_test.dart` on an
Android emulator or device.

Never use `flutter test --platform chrome` — this is not a web app.

See docs/TESTING_GUIDE.md for the full general-test vs integration-test
split and known local environment caveats.

---

# Route Planner

Start Hotel

↓

End Hotel

↓

Selected Places

↓

Optimize

↓

Display Polyline

↓

Display Total Time

↓

Display Total Distance

Route Type (derived automatically, not user-selected)

Start Hotel == End Hotel

↓

Round Trip

Start Hotel != End Hotel

↓

Hotel → Hotel

Round Trip

Start Hotel

↓

Places

↓

Start Hotel

Hotel → Hotel

Start Hotel

↓

Places

↓

End Hotel

---

# Place Selection Rules

Minimum

2

Maximum

10

Disable optimize button if

Less than 2 places selected.

---

# Loading Rules

Show loading indicator for

Video Analysis

Route Optimization

Bookmark Save

Hotel Save

Login

Never block UI.

---

# Error Handling

Display user-friendly messages.

Examples

Transcript unavailable.

Network error.

Login failed.

Route generation failed.

Do not display raw exception messages.

---

# Testing Strategy

Two test categories. Never mix them.

## General tests (`flutter test`, test/)

For anything that does not depend on a native platform channel:

Pure Dart logic

Provider state management

Repository logic (Dio response → model mapping)

JSON model parsing

Screens, using fakes for any platform-dependent feature they contain

## Integration tests (`flutter test integration_test -d <device>`)

For anything that needs a real native SDK — run only on an emulator/device:

Kakao Maps (kakao_map_plugin)

Kakao Login (once integrated)

WebView

Secure Storage

Any other Android/iOS native plugin

## Rule

Any platform-dependent feature (maps, login, secure storage, webview)
must be wrapped behind an interface/abstract repository with a real
implementation and a fake implementation, following the MapRepository /
KakaoMapRepository / FakeMapRepository pattern. Screens depend on the
interface, never the concrete native class, and accept it via a
constructor parameter defaulting to the real implementation.

Full details: docs/TESTING_GUIDE.md.

Kakao Developers console setup (app keys, platform registration, key
hashes) must be done by the account owner — Claude Code cannot do this.
See docs/KAKAO_SETUP.md for the checklist.

---

# Theme Rules

Light Theme

Primary Color

Blue

Rounded Buttons

Consistent spacing

Responsive layout

Use ThemeData.

Avoid hardcoded colors.

---

# Widget Rules

Reusable Widgets

PrimaryButton

LoadingIndicator

ErrorDialog

PlaceCard

HotelCard

BookmarkButton

RouteSummaryCard

VideoPlayerSection

KakaoMapWidget

Never duplicate widget code.

---

# Assets

Organize

assets/

images/

icons/

animations/

fonts/

Register assets in

pubspec.yaml

---

# Performance

Use ListView.builder

Use const constructors

Dispose controllers

Lazy load images

Avoid unnecessary rebuilds

---

# Secure Storage

Store

JWT

Refresh Token

User ID

Never store

API Keys

Passwords

OAuth Tokens

---

# Accessibility

Support different screen sizes.

Support dark mode later.

Use semantic labels.

Maintain touch-friendly spacing.

---

# Environment

Use

flutter_dotenv (core/config/env.dart reads via dotenv.env, loaded from .env in main.dart)

.env is git-ignored. Copy .env.example to .env locally and fill in real
values — never commit .env, never hardcode its values in source.

Environment Variables (see .env.example)

API_BASE_URL

KAKAO_JAVASCRIPT_KEY (Kakao JavaScript key, used by kakao_map_plugin for map rendering — see docs/KAKAO_SETUP.md for why this plugin needs a JavaScript key, not a Native App Key)

KAKAO_NATIVE_APP_KEY (Kakao Login via kakao_flutter_sdk_user — consumed by KakaoAuthService.initialize() and, on Android, by build.gradle.kts' manifest placeholder; iOS needs the same value duplicated into ios/Flutter/KakaoKeys.xcconfig, see docs/KAKAO_SETUP.md)

Never hardcode URLs or API keys in source.

Setup:

cp .env.example .env
# then edit .env with real values

flutter run

---

# Native Platform Registration (Kakao Developers)

Kakao Maps requires the app's Android package name (applicationId) and
iOS bundle ID to be registered under the Kakao app's platform settings
on Kakao Developers, along with the Android key hash.

android/app/build.gradle.kts → defaultConfig.applicationId

ios/Runner.xcodeproj → PRODUCT_BUNDLE_IDENTIFIER

This registration must be done manually on the Kakao Developers console
before the map will load on a real device; it cannot be automated from
this repo.

Full checklist: docs/KAKAO_SETUP.md

Package/bundle ID rename procedure: docs/PACKAGE_RENAME_GUIDE.md

---

# Claude Code Instructions

When generating Flutter code

Always use Provider.

Always use Repository Pattern.

Always use Dio.

Always create Models.

Always create reusable widgets.

Always separate UI and state.

Never put business logic inside widgets.

Never call AI APIs directly.

Always call Backend.

Always show loading state.

Always show error state.

Always support responsive layouts.

Always use strongly typed models.

Never target Flutter Web. Never use package:web or dart:js_interop.

Always wrap native platform features (maps, login, secure storage,
webview) behind an interface with a real implementation and a fake
implementation for tests.

Generate production-ready Flutter code.