# BoBo Timeline Data Processing Reference

This document describes how BoBo transforms raw sensing data into the clean, human-readable timeline shown in the app UI. Use this as a reference for building similar behavioral data processing pipelines.

## Architecture Overview

```
Raw Sources (phone sensors + HealthKit + Watch)
  │
  ├─ Phone CoreMotion ──────────┐
  ├─ Apple HealthKit ───────────┤
  ├─ Screen/Battery/WiFi/BT ───┤
  ├─ Location (GPS + Places) ───┤
  └─ Audio (microphone) ────────┘
          │
          ▼
  eventsForSelectedDate          ← merge phone + HealthKit, suppress phone motion during Watch workouts
          │
          ▼
  filteredSensingEvents          ← remove noise: dedup motion episodes, time-window dedup health metrics, aggregate screen events, drop raw steps
          │
          ▼
  deduplicatedSensingEvents      ← remove motion events that overlap with Health module activities (walking/running/cycling logged manually)
          │
          ▼
  timelineItems                  ← merge with narrations, nudges, meals, activities; hide screen "off" + audio transients; sort newest-first
          │
          ▼
  Display (type + detail text)   ← human-readable summary per modality
```

## Stage 1: Source Merging (`eventsForSelectedDate`)

Combines two data sources for the selected date:

1. **Phone sensing events** (`SensingEngine.recentEvents` for today, `BoboDataStore` for past dates)
   - Motion, screen, battery, WiFi, Bluetooth, audio, photo, call, location
2. **HealthKit data** (queried directly from Apple Health)
   - Heart rate, HRV, sleep, steps, active energy, basal energy, respiratory rate, blood oxygen, noise exposure, workouts

**Key rule**: Watch workouts take priority over phone CoreMotion. During workout time intervals, phone motion events are suppressed (Watch wrist sensors are more accurate).

## Stage 2: Noise Filtering (`filteredSensingEvents`)

### Motion: Episode Grouping (HAR — Human Activity Recognition)
- Consecutive same-activity events within 5 minutes are collapsed
- Keep only the first event of each episode (the transition point)
- Episode events carry: `activityType`, `duration` (seconds), `nextActivity`
- Result: "Walking (1m 8s) → Stationary" instead of dozens of raw accelerometer readings

### Time-Window Deduplication
Keep at most 1 event per time window for noisy modalities:

| Modality | Window | Rationale |
|----------|--------|-----------|
| heartRate | 60s | Watch writes multiple samples per reading |
| hrv | 60s | Same as heart rate |
| activeEnergy | 300s | Cumulative, updates frequently |
| basalEnergy | 300s | Cumulative, updates frequently |
| respiratoryRate | 600s | Low-variance metric |
| bloodOxygen | 60s | Watch writes multiple samples per measurement |
| noiseExposure | 600s | Can fire every minute; anomaly: 1/min |
| bluetooth | 3600s | Periodic scans, low information density |

### Screen: Hourly Aggregation
- Individual screen on/off pairs within the same hour are aggregated into a single "hourly_aggregate" event
- Shows: "Screen · 5 opens · 42m total"
- On-duration and off-duration enrichment: "Screen On · 5m 30s · Off for 15m"

### Steps: Removed Entirely
- Raw step events are excluded from the timeline (shown in the overview summary card instead)
- `daySummary.totalSteps` uses the max value across all step events for the day

### Location: Significant Change Only
- Only kept when position changed > ~100m from last location, OR 1+ hour gap since last event
- Prevents flood of GPS updates while stationary

## Stage 3: Health Activity Deduplication (`deduplicatedSensingEvents`)

When the user logs an activity manually via the Health module (e.g., "Walking 30 min"), motion events that overlap within ±10 minutes of that activity are removed.

Overlapping activity types: `walking`, `running`, `cycling`

This prevents showing both "Motion: Walking (25m) → Stationary" AND "Walking: 30m · 150 cal burned" for the same real-world activity.

## Stage 4: Timeline Assembly (`timelineItems`)

Merges 5 item types into a single chronological list:

| Type | Source | Example |
|------|--------|---------|
| `.sensing(SensingEvent)` | Filtered sensing events | "Motion: Walking (8s) → Stationary" |
| `.narration(Narration)` | Voice/text diary entries | "Voice Narration: I just went for a walk..." |
| `.nudge(Nudge)` | AI-generated insights from Bo | "Bo says: You've been sitting for 2 hours..." |
| `.meal(FoodEntry)` | Logged meals via Health module | "Lunch: Chicken salad, 450 cal" |
| `.activity(ActivityEntry)` | Logged activities via Health module | "Gym: 45m · 300 cal burned" |

**Hidden events** (filtered out before display):
- Screen `state == "off"` — data folded into the preceding "on" event
- Audio `status == "listening"` — transient indicator, not a real event
- Audio `status == "speaker_update"` — enriches existing transcript, not a new row

Sorted **newest-first**.

## Stage 5: Display Text Generation

Each timeline item produces a `(type: String, detail: String)` tuple:

### Sensing Events by Modality

#### Motion
- **Payload fields**: `activityType`, `duration` (seconds), `nextActivity`
- **Episode display**: `"{Activity} ({duration}) → {NextActivity}"`
- **Ongoing**: `"{Activity}"`
- **Examples**: `"Walking (1m 8s) → Stationary"`, `"Stationary (25m 44s) → Stationary"`, `"Automotive"`

#### Heart Rate
- **Payload fields**: `bpm`, `min`, `max`, `anomaly`
- **Single reading**: `"{bpm} BPM"`
- **Aggregated range**: `"{avg} BPM ({min}–{max})"`
- **Anomaly**: `"⚠ {bpm} BPM"` (prefixed with warning)
- **Examples**: `"91 BPM"`, `"85 BPM (72–98)"`, `"⚠ 120 BPM"`

#### HRV (Heart Rate Variability)
- **Payload fields**: `sdnn`
- **Display**: `"{sdnn} ms SDNN"`
- **Example**: `"52 ms SDNN"`

#### Sleep
- **Payload fields**: `stage`
- **Stage mapping**: `inBed` → "In Bed", `awake` → "Awake", `asleep` → "Asleep", `core` → "Core Sleep", `deep` → "Deep Sleep", `rem` → "REM Sleep"
- **Example**: `"Deep Sleep"`

#### Location
- **Priority chain** (first non-empty wins):
  1. Semantic label + place name: `"Home · 123 Main St"`
  2. Semantic label only: `"Home"`
  3. Google Places POI: `"Starbucks (cafe)"`
  4. Google Geocoding address: `"Downtown · 456 Elm Ave"`
  5. Fallback coordinates: `"(38.03, -78.51)"`
- **Payload fields**: `semanticLabel`, `placeName`, `placeType`, `address`, `neighborhood`, `latitude`, `longitude`, `visit`

#### Screen
- **Hourly aggregate**: `"Screen · {count} opens · {totalDuration} total"`
- **Screen on event**: `"Screen On · {onDuration} · Off for {offDuration}"`
- **Payload fields**: `state` (on/off/hourly_aggregate), `count`, `totalDuration`, `onDuration`, `offDuration`
- **Examples**: `"Screen · 3 opens · 1m 36s total"`, `"Screen On · 5m 30s"`

#### Battery
- **Payload fields**: `level`
- **Display**: `"{level}%"`
- **Example**: `"95%"`

#### Active Energy / Resting (Basal) Energy
- **Payload fields**: `kcal`, `hourLabel`, `ongoing`
- **Ongoing (current hour)**: `"{kcal} kcal so far since {hour}"`
- **Completed hour**: `"{hourLabel}: {kcal} kcal"`
- **Examples**: `"40 kcal so far since 2"`, `"12-13: 85 kcal"`

#### Workout
- **Payload fields**: `type`, `calories`
- **Display**: `"{type} — {calories} kcal"`
- **Example**: `"Running — 120 kcal"`

#### Respiratory Rate
- **Payload fields**: `breathsPerMin`
- **Display**: `"{rate} breaths/min"`
- **Example**: `"18 breaths/min"`

#### Blood Oxygen
- **Payload fields**: `spo2`
- **Display**: `"{spo2}% SpO2"` (prefixed with ⚠ if < 95%)
- **Example**: `"98% SpO2"`, `"⚠ 93% SpO2"`

#### Noise Level
- **Payload fields**: `decibels`
- **Display**: `"{db} dB"`
- **Example**: `"75 dB"`

#### Phone Call
- **Payload fields**: `direction`/`state`, `status`, `duration`
- **Answered**: `"{Direction} Call · {duration}"`
- **Missed**: `"Missed Call"`
- **No answer**: `"Outgoing Call · no answer"`
- **Examples**: `"Incoming Call · 3m 24s"`, `"Missed Call"`

#### Wi-Fi
- **Payload fields**: `ssid`
- **Display**: `"{ssid}"` or `"disconnected"`

#### Bluetooth
- **Payload fields**: `deviceCount`, `namedCount`
- **Aggregated scan**: `"{total} devices nearby ({named} named)"`
- **Example**: `"5 devices nearby (3 named)"`

#### Audio (Ambient Transcript)
- **Payload fields**: `status`, `text`, `speaker`
- **Transcript**: `"{Speaker}: {text preview (60 chars)}..."`
- **Error**: `"{error message}"`
- **Example**: `"John: Hey, are you coming to the meeting later today?..."`

#### Photo
- **Display**: `"Photo"` (static)

### Non-Sensing Items

| Type | Title | Detail |
|------|-------|--------|
| Voice Narration | "Voice Narration" | Full transcript text |
| Text Narration | "Text Narration" | Transcript or "Text entry" |
| Nudge | "Bo says" | Nudge content |
| Meal | Meal type ("Breakfast", "Lunch", etc.) | AI summary or food description |
| Activity | Activity type ("Gym", "Walking", etc.) | "{duration} · {calories} cal burned" |

## Duration Formatting

All durations use the same formatter:
```
< 60s:  "{s}s"              → "8s"
< 60m:  "{m}m {s}s"         → "1m 8s"   (or "{m}m" if s=0)
≥ 60m:  "{h}h {m}m"         → "2h 15m"  (or "{h}h" if m=0)
```

## Day Summary (Overview Card)

Aggregated stats from all events for the day:

| Field | Source |
|-------|--------|
| `totalSteps` | Max value across all `steps` events |
| `activityBreakdown` | Count of motion events per `activityType` |
| `locationChanges` | Count of location events |
| `screenEvents` | Count of screen events |
| `narrationCount` | Count of narrations for the day |
| `nudgeCount` | Count of nudges for the day |
| `totalCaloriesConsumed` | Sum from Health module food entries |
| `totalCaloriesBurned` | Sum from Health module activity entries |
| `totalActivityMinutes` | Sum of activity durations from Health module |

## Output JSON Schema

The processed timeline is served as a single JSON object:

```json
{
  "date": "2026-03-02 (Monday)",
  "totalEvents": 486,
  "summary": {
    "steps": 10446,
    "narrations": 4,
    "nudges": 5,
    "screenEvents": 46,
    "locationChanges": 54,
    "caloriesConsumed": 1030,
    "caloriesBurned": 393,
    "activityMinutes": 72,
    "activityBreakdown": {
      "stationary": 21,
      "walking": 20,
      "automotive": 4
    }
  },
  "items": [
    {"time": "2:37 PM", "type": "Heart Rate", "detail": "84 BPM"},
    {"time": "2:35 PM", "type": "Wi-Fi", "detail": "disconnected"},
    {"time": "2:35 PM", "type": "Battery", "detail": "95%"},
    {"time": "2:20 PM", "type": "Motion", "detail": "Walking"},
    {"time": "2:09 PM", "type": "Motion", "detail": "Stationary (11m 28s) → Walking"},
    {"time": "2:00 PM", "type": "Screen", "detail": "Screen · 3 opens · 1m 36s total"},
    {"time": "12:08 PM", "type": "Location", "detail": "University of Virginia - Event Planning"},
    ...
  ]
}
```

Each item: `{time: "h:mm AM/PM", type: "Modality Name", detail: "human-readable summary"}`.
Items sorted newest-first.

## Raw → Processed: Compression Ratio

Example from 2026-03-02:
- **Raw sensing events**: 3,581 (from bridge server `/bobo/sensing?date=2026-03-02`)
- **Processed timeline items**: 486 (after filtering + merging meals/activities/narrations/nudges)
- **Compression**: ~7.4x reduction

Breakdown of what gets filtered:
- basalEnergy: 1,272 → 15 (time-window dedup, 1 per 5 min)
- heartRate: 989 → 249 (time-window dedup, 1 per min)
- steps: 656 → 0 (removed entirely, shown in summary)
- motion: 246 → 41 (episode grouping)
- activeEnergy: 114 → 15 (time-window dedup)
- location: 93 → 14 (significant change only)
- screen: 60 → 7 (hourly aggregation)
- noiseExposure: 34 → 26 (time-window dedup)
- bluetooth: 27 → 5 (1 per hour)
