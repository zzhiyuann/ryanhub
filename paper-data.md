# RyanHub — Empirical Data for UIST Paper

> Data collected: 2026-03-03
> Repository: `/Users/zwang/projects/ryanhub/`
> All numbers are exact counts from the codebase.

---

## 1. Codebase Statistics

### Overall Scale

| Metric | Count |
|--------|-------|
| Total commits | 224 |
| Total Swift LOC (iOS app) | 36,517 |
| Total Swift files | 94 |
| Total Python files (project-owned, excl. venvs) | 15 |
| Total TypeScript/JSX files (BookFactory service) | ~90+ (src/) |
| Total backend LOC (project-owned) | 21,121 |
| UI test files | 13 |
| UI test LOC | 1,606 |

### Backend LOC Breakdown

| File/Service | LOC |
|--------------|-----|
| `scripts/bridge-server.py` | 2,117 |
| `scripts/calendar-sync-server.py` | 517 |
| `scripts/diarization-server.py` | 1,313 |
| `scripts/start-all-services.sh` | 625 |
| `services/dispatcher/dispatcher/` (Python) | 5,337 |
| `services/dispatcher/tests/` (Python) | 5,928 |
| `services/dispatcher/scripts/claude-sidecar.mjs` | 106 |
| `services/bookfactory/src/` (Next.js TypeScript) | 5,694 |
| `services/bookfactory/server.mjs` | 53 |
| `services/bookfactory/books/md_to_pdf.py` | 56 |
| **Total backend (code + tests)** | **21,746** |
| **Total backend (excl. tests)** | **15,818** |

### Toolkit Module Statistics

| Module | Files | LOC | DataProvider | Bridge Endpoint |
|--------|-------|-----|--------------|-----------------|
| Bobo (Behavioral Sensing) | 21 | 8,491 | Yes | Yes (12 endpoints) |
| BookFactory | 14 | 3,155 | Yes | Yes (via HTTPS :3443) |
| Calendar | 5 | 1,656 | Yes | Yes (7 endpoints) |
| Fluent (Vocabulary) | 11 | 10,241 | Yes | No (local only) |
| Health | 9 | 4,152 | Yes | Yes (6 endpoints) |
| Parking | 4 | 1,132 | Yes | Yes (4 endpoints) |
| **Total toolkit** | **64** | **28,827** | **6/6** | **5/6** |

### Non-Toolkit Module Statistics

| Module | Files | LOC |
|--------|-------|-----|
| Core (Design, Networking, Models, Localization) | 15 | 1,640 |
| App (Entry point, TabView) | 2 | 330 |
| Chat (AI chat interface) | 6 | 3,090 |
| Settings | 2 | 640 |
| Toolkit root (ToolkitHomeView) | 1 | 606 |
| **Total non-toolkit** | **26** | **6,306** |

### UI Test Suite

| Test File | LOC |
|-----------|-----|
| `AgenticExplorer.swift` | 298 |
| `CrossModuleTests.swift` | 193 |
| `RyanHubUITestBase.swift` | 161 |
| `HealthTests.swift` | 133 |
| `BookFactoryTests.swift` | 121 |
| `FluentTests.swift` | 108 |
| `ChatTests.swift` | 100 |
| `ToolkitTests.swift` | 95 |
| `TerminalTests.swift` | 89 |
| `ParkingTests.swift` | 81 |
| `SettingsTests.swift` | 80 |
| `CalendarTests.swift` | 79 |
| `TabNavigationTests.swift` | 68 |
| **Total** | **13 files, 1,606 LOC** |

---

## 2. Development Timeline

| Metric | Value |
|--------|-------|
| First commit | 2026-02-25 14:55:39 -0500 |
| Most recent commit | 2026-03-02 12:25:50 -0500 |
| Development span | 6 calendar days |
| Active development days | 5 |
| Total commits | 224 |
| Average commits per active day | 44.8 |

### Commits Per Day

| Date | Commits |
|------|---------|
| 2026-02-27 | 102 |
| 2026-02-25 | 56 |
| 2026-02-28 | 25 |
| 2026-02-26 | 24 |
| 2026-03-02 | 17 |

### Git Diff Statistics (cumulative)

| Metric | Count |
|--------|-------|
| Total files changed (across all commits) | 870 |
| Total insertions | 73,480 |
| Total deletions | 9,925 |
| Net lines added | 63,555 |

---

## 3. PersonalContext Bus Data

### Architecture

The PersonalContext system is defined in two files:
- **Protocol**: `RyanHub/Core/PersonalContext/ToolkitDataProvider.swift` (38 LOC)
- **Registry**: `RyanHub/Core/PersonalContext/PersonalContext.swift` (49 LOC)

### Registered Providers: 6

| Provider | Toolkit ID | Display Name | Keywords Count |
|----------|-----------|--------------|----------------|
| `HealthDataProvider` | `health` | Health Data | 26 (EN + ZH) |
| `FluentDataProvider` | `fluent` | Fluent Vocabulary Data | 12 (EN + ZH) |
| `ParkingDataProvider` | `parking` | Parking Data | 10 (EN + ZH) |
| `CalendarDataProvider` | `calendar` | Calendar Data | 10 (EN + ZH) |
| `BookFactoryDataProvider` | `bookfactory` | Book Library Data | 8 (EN + ZH) |
| `BoboDataProvider` | `bobo` | BoBo Behavioral Sensing | 24 (EN + ZH) |

### Context Injection Mechanism

- **Strategy**: ALL providers are injected into EVERY message (no keyword filtering)
- The agent receives the full personal context and decides relevance autonomously
- Context is wrapped in `[Personal Context]` / `[End Personal Context]` delimiters
- Each provider's `buildContextSummary()` returns a structured text block with:
  - Current state data (read from UserDefaults, files, or cached objects)
  - Action hints (curl commands for writing data back via bridge server)
- `buildFullSnapshot()` provides a complete dump for daily briefings

### Provider Summary Content

| Provider | Data Sections | Action Endpoints |
|----------|---------------|-----------------|
| Health | Weight (trend), Food (today+yesterday with macros), Activity (today with exercises) | 3 POST endpoints (food/add, weight/add, activity/add) |
| Fluent | Total vocab count, streak, lifetime stats, today's session, due cards, category breakdown | None (in-app only) |
| Parking | Today's status, upcoming skip dates, monthly cost, purchased days | File read/write for skip-dates.txt |
| Calendar | Today's events, tomorrow's events, week events, sync freshness | Create/update/delete via Calendar tab |
| BookFactory | Library count, audiobook stats, recent 5 books | 1 POST endpoint (generate via API) |
| Bobo | API usage instructions for timeline read + diary write | 2 endpoints (timeline GET, narrations/add POST) |

---

## 4. Bobo Sensing Pipeline

### Sensors: 10 Total

| Sensor | File | LOC | What It Collects |
|--------|------|-----|-----------------|
| AudioStreamSensor | `AudioStreamSensor.swift` | 507 | Always-on microphone → WebSocket to diarization server; Silero VAD, Whisper transcription, speaker diarization |
| MotionSensor | `MotionSensor.swift` | 151 | CoreMotion activity type (walking, running, driving, stationary, cycling) + step counts; episode-based transitions |
| ScreenSensor | `ScreenSensor.swift` | 106 | Screen on/off via protectedData notifications; on-duration and off-duration tracking |
| WiFiSensor | `WiFiSensor.swift` | 100 | Current WiFi SSID for home/office detection |
| HealthSensor | `HealthSensor.swift` | 901 | Heart rate (1-min aggregates with anomaly detection), HRV, sleep stages, workout completions, active/basal energy, respiratory rate, blood oxygen, noise exposure via HealthKit |
| LocationSensor | `LocationSensor.swift` | 203 | Significant location changes (~500m threshold) + visit monitoring (arrivals/departures); reverse geocoding via bridge server |
| CallSensor | `CallSensor.swift` | 114 | Phone call state transitions via CXCallObserver; consolidated per-call events with duration |
| BluetoothSensor | `BluetoothSensor.swift` | 171 | Nearby Bluetooth peripherals scan; detects AirPods, Watch, car Bluetooth; aggregated per scan cycle |
| BatterySensor | `BatterySensor.swift` | 110 | Battery level and charging state |
| PhotoLibrarySensor | `PhotoLibrarySensor.swift` | 157 | New photo detection from system photo library; compressed thumbnail saved to disk |
| **SensingEngine** (orchestrator) | `SensingEngine.swift` | 527 | Coordinates all sensors; enrichment (call duration, motion episode duration, audio speaker labels) |

### Code Distribution

| Category | LOC |
|----------|-----|
| Sensing code (10 sensors + SensingEngine) | 3,047 |
| UI + ViewModel + Models + Services | 5,444 |
| **Total Bobo module** | **8,491** |
| Sensing-to-UI ratio | 36% sensing / 64% UI |

### Deduplication & Aggregation Rules

The BoboViewModel implements a multi-stage filtering pipeline:

1. **Steps removal**: Step count events removed from timeline entirely (shown in overview card via `daySummary.totalSteps`)

2. **Motion HAR episode grouping**: Consecutive same-activity events within 5 minutes are collapsed to keep only the first (transition) event

3. **Location filtering**: Only kept when position changed >~100m or 1+ hour gap since last event

4. **Time-window deduplication** (per modality):
   | Modality | Window |
   |----------|--------|
   | Heart Rate | 1 per 60s (anomalies bypass) |
   | HRV | 1 per 60s |
   | Active Energy | 1 per 300s (5 min) |
   | Basal Energy | 1 per 300s (5 min) |
   | Respiratory Rate | 1 per 600s (10 min) |
   | Blood Oxygen | 1 per 60s |
   | Noise Exposure | 1 per 600s (anomaly >80 dBA: 1 per 60s) |
   | Bluetooth | 1 per 3600s (1 hour) |

5. **Health activity deduplication**: Motion events that overlap (within +/-10 minutes) with a Health module activity of matching type (walking, running, cycling) are removed to avoid duplicate reporting

6. **Screen aggregation**: "on" events aggregated into hourly buckets

---

## 5. Module Architecture Metrics

### Detailed File Taxonomy Per Module

| Module | Views | ViewModels | Models | DataProvider | Services | Other | Total Files | Total LOC |
|--------|-------|------------|--------|--------------|----------|-------|-------------|-----------|
| Bobo | 3 (BoboView, TimelineEventRow, NarrationRecordButton) | 1 (BoboViewModel) | 3 (SensingEvent, Narration, Nudge) | 1 | 2 (BoboDataStore, BoboSyncService) | 11 (Sensing/) | 21 | 8,491 |
| BookFactory | 7 (BookFactoryView, BookLibraryView, BookReaderView, AudioPlayerView, MiniPlayerView, QueueManagerView, BookFactorySettingsView) | 3 (BookFactoryViewModel, AudioPlayerViewModel, QueueViewModel) | 1 (BookModels) | 1 | 2 (BookFactoryAPI, AudioService) | 0 | 14 | 3,155 |
| Calendar | 1 (CalendarPluginView) | 1 (CalendarViewModel) | 1 (CalendarModels) | 1 | 1 (CalendarService) | 0 | 5 | 1,656 |
| Fluent | 5 (FluentView, FluentReviewView, FluentVocabularyView, FluentVocabularyDetailView, FluentSettingsView) | 1 (FluentViewModel) | 1 (FluentModels) | 1 | 0 | 3 (FluentStore, FSRSEngine, FluentSeedData) | 11 | 10,241 |
| Health | 4 (HealthView, DailySummaryView, WeightLogView, CameraView) | 1 (HealthViewModel) | 1 (HealthModels) | 1 | 1 (FoodAnalysisService) | 1 (WeightTimelineChart) | 9 | 4,152 |
| Parking | 1 (ParkingView) | 1 (ParkingViewModel) | 1 (ParkingModels) | 1 | 0 | 0 | 4 | 1,132 |

### Bridge Server Endpoint Mapping

| Module | Endpoints |
|--------|-----------|
| Bobo/POPO | `/popo/sensing`, `/popo/narrations`, `/popo/nudges`, `/popo/daily-summary`, `/popo/audio`, `/popo/audio/<filename>`, `/popo/narrations/analyze`, `/popo/analyze`, `/popo/location/enrich`, `/popo/location/learn-place`, `/popo/narrations/add`, `/popo/timeline` (12 endpoints) |
| Health | `/health-data/weight` (GET/POST), `/health-data/food` (GET/POST), `/health-data/activity` (GET/POST), `/analyze`, `/analyze-activity` (6+ endpoints) |
| Parking | `/parking/skip-dates` (GET/POST), `/parking/last-status`, `/parking/purchase-history` (4 endpoints) |
| Chat | `/chat/messages` (GET/POST/DELETE) (3 endpoints) |
| Calendar | Separate server on :18791 — `/calendars`, `/events` (GET/POST/PUT/DELETE), `/agent`, `/health` (7 endpoints) |
| BookFactory | Separate Next.js server on :3443 — books, audiobook, queue, auth, settings APIs |

---

## 6. Backend Service Architecture

### Services Overview

| Service | Port | Protocol | LOC | Language |
|---------|------|----------|-----|----------|
| Bridge Server | 18790 | HTTP | 2,117 | Python |
| Calendar Sync Server | 18791 | HTTP | 517 | Python |
| Diarization Server | 18793 | HTTP/WebSocket | 1,313 | Python |
| Dispatcher | 8765 | WebSocket | 5,337 (+ 5,928 tests) | Python |
| Book Factory | 3443/3000 | HTTPS/HTTP | 5,747 | TypeScript (Next.js) |
| Service Manager | — | Shell | 625 | Bash |

### Bridge Server Endpoints: 26

```
POST /analyze                    — Food analysis (text + image) via claude CLI
POST /analyze-activity           — Activity analysis via claude CLI
GET  /health                     — Health check

GET  /parking/skip-dates         — Read skip dates
POST /parking/skip-dates         — Write skip dates
GET  /parking/last-status        — Last purchase status
GET  /parking/purchase-history   — Purchase history

GET  /health-data/weight         — Read weight entries
POST /health-data/weight         — Write weight entries
GET  /health-data/food           — Read food entries
POST /health-data/food           — Write food entries
GET  /health-data/activity       — Read activity entries
POST /health-data/activity       — Write activity entries

GET    /chat/messages             — Read chat messages
POST   /chat/messages             — Write chat messages
DELETE /chat/messages             — Clear chat messages

GET/POST /popo/sensing            — Sensing events
GET/POST /popo/narrations         — Voice diary entries
GET/POST /popo/nudges             — Proactive nudge records
GET/POST /popo/daily-summary      — Daily behavior summaries
POST     /popo/audio              — Upload audio file
GET      /popo/audio/<filename>   — Retrieve audio file
POST     /popo/narrations/analyze — Transcribe + affective analysis
POST     /popo/analyze            — Behavioral analysis (nudge generation)
POST     /popo/location/enrich    — Reverse geocode + place enrichment
POST     /popo/location/learn-place — Teach named places
```

### Calendar Sync Server Endpoints: 7

```
GET    /health                   — Health check
GET    /calendars                — List all calendars with colors
GET    /events?start=ISO&end=ISO — Fetch events from all calendars
POST   /events                   — Create event (structured JSON)
PUT    /events/<id>              — Update event
DELETE /events/<id>?calendar_id= — Delete event
POST   /agent                    — Natural language command via Claude CLI
```

### Dispatcher WebSocket Message Types

**Client → Server (6 types):**
| Type | Description |
|------|-------------|
| `ping` | Keepalive |
| `command` | Shell command execution |
| `answer` | Response to a question from server |
| `edit` | Edit a previous message |
| `notification` | Push notification from iOS |
| `message` | Chat message from user |

**Server → Client (8 types):**
| Type | Description |
|------|-------------|
| `pong` | Ping response |
| `ack` | Message received acknowledgment |
| `response` | AI response (supports streaming flag) |
| `error` | Error message |
| `question` | Question requiring user answer |
| `command_result` | Shell command output |
| `edit_ack` | Edit confirmation |
| `notification` | Server-initiated notification |
| `status` | Status update |
| `session_complete` | Session finished |

### Backend LOC Per Service

| Service | Production Code | Test Code | Total |
|---------|----------------|-----------|-------|
| Bridge Server | 2,117 | — | 2,117 |
| Calendar Sync Server | 517 | — | 517 |
| Diarization Server | 1,313 | — | 1,313 |
| Dispatcher | 5,443 (5,337 Python + 106 JS) | 5,928 | 11,371 |
| Book Factory | 5,803 (5,694 TS + 53 mjs + 56 py) | — | 5,803 |
| Service Manager | 625 | — | 625 |
| **Total** | **15,818** | **5,928** | **21,746** |

---

## 7. CLAUDE.md System

### File: `/Users/zwang/projects/ryanhub/CLAUDE.md`

| Metric | Count |
|--------|-------|
| Total lines | 197 |
| Top-level sections (`##`) | 10 |
| Subsections (`###`) | 15 |
| Total sections + subsections | 25 |
| Git commits modifying CLAUDE.md | 10 |

### Section Structure

```
## Overview
## Repository Structure
## External Data (NOT in repo)
## Build Instructions
  ### iOS App
  ### Backend Services
  ### Book Factory Server (standalone)
  ### Dispatcher (standalone)
## Backend Services (table)
## Design System (MUST follow for all UI work)
  ### Colors
  ### Typography
  ### Layout Constants
  ### Reusable Components
## Technical Requirements (iOS)
## Toolkit Navigation
## Known Issues
## Agent Coordination — Leadership Learnings
  ### Core Principle
  ### Context is Everything
  ### Decomposition Strategy
  ### Use Background Agents
  ### Verification Protocol
  ### Worktree Merge Protocol
  ### Self-Assessment Signals
```

### Content Categories

| Category | Lines (approx) | Sections |
|----------|----------------|----------|
| Project overview & structure | ~50 | Overview, Repository Structure, External Data |
| Build & deploy instructions | ~30 | Build Instructions (iOS, Backend, BookFactory, Dispatcher) |
| Backend service registry | ~10 | Backend Services table |
| Design system rules | ~30 | Colors, Typography, Layout, Components |
| Technical requirements | ~10 | iOS constraints |
| Known issues | ~6 | 5 documented issues |
| Agent coordination learnings | ~40 | 7 subsections of leadership/coordination rules |

### Known Issues Documented: 5

1. Food Analysis JSON decoder needs `keyDecodingStrategy = .convertFromSnakeCase`
2. Food Analysis `AnalyzedFoodItem.id` uses `name` — duplicate ID collision risk
3. WebSocketClient `@Observable` mutated from non-MainActor methods
4. Voice messages: No playback (waveform is display-only)
5. CalendarViewModel requires calendar-sync-server.py running for real data

### CLAUDE.md Modification History (10 commits)

```
1fc3fa9 Fix POPO plugin crash on launch
4629455 Rename food-analysis-server references to bridge-server
08dfd2f feat: rebuild Calendar plugin with real Google Calendar integration
7a59ab4 refactor: consolidate into monorepo — add services/bookfactory & services/dispatcher
f56b99d Update CLAUDE.md: reflect single-chat architecture
124b015 Update CLAUDE.md: mark resolved issues, add agent dispatch lessons
bc59f9d Update CLAUDE.md: mark resolved issues from today's fixes
12d8d20 Update CLAUDE.md: add backend services, agent dispatch playbook, and known issues backlog
112390e Rename project from CortexApp to RyanHub
2c24072 Initialize Cortex iOS app: foundation, design system, chat, settings, and toolkit scaffold
```

---

## 8. Git Diff Statistics

### Cumulative Change Volume

| Metric | Count |
|--------|-------|
| Total file change operations across all commits | 870 |
| Total insertions | 73,480 |
| Total deletions | 9,925 |
| Net lines added | 63,555 |

### Development Velocity

| Metric | Value |
|--------|-------|
| Development span | 6 calendar days (Feb 25 – Mar 2, 2026) |
| Active coding days | 5 |
| Total commits | 224 |
| Average commits/active day | 44.8 |
| Peak day | Feb 27 (102 commits) |
| Net LOC/active day | ~12,711 |
| Insertions/active day | ~14,696 |

### Weekly Breakdown

| Week | Commits |
|------|---------|
| 2026-W09 (Feb 24–Mar 2) | 207 |
| 2026-W10 (Mar 2–) | 17 |

---

## Summary Statistics for Paper

### System Scale

- **Total LOC**: ~58,263 (36,517 Swift + 15,818 backend production + 5,928 backend tests)
- **Total files**: ~120+ source files (94 Swift + 15 Python + many TS/JS)
- **6 toolkit modules**, each with its own `ToolkitDataProvider` for context injection
- **10 sensors** in the Bobo behavioral sensing pipeline
- **33+ REST endpoints** across 3 HTTP servers
- **14 WebSocket message types** (6 client→server, 8+ server→client)
- **4 backend services** + 1 service manager script

### Development Process

- **224 commits in 5 active days** (44.8 commits/day average)
- **73,480 insertions, 9,925 deletions** across 870 file-change operations
- **CLAUDE.md updated 10 times** — living document for agent coordination
- **13 UI test files** (1,606 LOC) including an agentic explorer
- Peak productivity: **102 commits on Feb 27** (day 3)

### PersonalContext Bus

- **6 registered providers**, all returning structured context every message
- Context includes: health metrics, food logs, calendar events, vocabulary stats, parking status, behavioral timeline
- Each provider outputs **action hints** (curl commands) so the agent can write data back
- Bilingual keyword support (English + Chinese) across all providers
