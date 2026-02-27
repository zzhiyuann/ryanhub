# Ryan Hub — Personal Assistant Monorepo

## Overview

Ryan Hub is a self-contained monorepo for a personal assistant iOS app and its backend services. It combines:
- **iOS app** (SwiftUI) — AI chat, toolkit with plugins, settings
- **Book Factory server** (Next.js) — Book platform API on HTTPS :3443
- **Dispatcher** (Python) — WebSocket chat backend on :8765

## Repository Structure

```
ryanhub/
├── RyanHub/                         # iOS app source
│   ├── App/                         # Entry point, root TabView
│   ├── Core/                        # Design, Networking, Localization, Models
│   └── Modules/                     # Chat, Toolkit (BookFactory, Fluent, Parking, Calendar, Health), Settings
├── RyanHubUITests/                  # UI tests (XCUITest)
├── services/
│   ├── bookfactory/                 # Book Factory Next.js server
│   │   ├── src/                     # Next.js App Router source
│   │   ├── server.mjs              # Custom HTTPS server wrapper
│   │   ├── package.json
│   │   ├── certs/                   # (gitignored) mkcert TLS certs
│   │   └── .env                     # (gitignored) secrets
│   └── dispatcher/                  # Dispatcher Python package
│       ├── dispatcher/              # Python source
│       ├── pyproject.toml
│       ├── config.example.yaml
│       └── .venv/                   # (gitignored) Python venv
├── scripts/
│   ├── start-all-services.sh        # Master service manager (start|stop|status|restart)
│   ├── food-analysis-server.py      # Nutrition analysis bridge (HTTP :18790)
│   ├── calendar-sync-server.py     # Google Calendar bridge (HTTP :18791)
│   └── calendar-agent-memory.json  # Calendar agent persistent memory
├── project.yml                      # XcodeGen project spec
├── CLAUDE.md                        # This file
└── .gitignore
```

## External Data (NOT in repo)

- **Book source files**: `/Users/zwang/bookfactory/` (generated books, `topic_backlog.md`)
- **Database + audio**: `/Users/zwang/projects/bookfactory/data/` (`bookfactory.db`, `audio/`)
- **Dispatcher config**: `~/.config/dispatcher/config.yaml`

Environment variables used by services:
- `BOOKFACTORY_DATA_DIR` — path to DB + audio dir (default: `../data` relative to server)
- `BOOK_SOURCE_DIR` — path to generated book files (default: `/Users/zwang/bookfactory`)
- `BACKLOG_PATH` — path to `topic_backlog.md` (default: `/Users/zwang/bookfactory/topic_backlog.md`)

## Build Instructions

### iOS App
```bash
cd /Users/zwang/projects/ryanhub
xcodegen generate
xcodebuild -scheme RyanHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
open RyanHub.xcodeproj
```
Bundle ID: `com.zwang.ryanhub.RyanHub`

### Backend Services
```bash
# Start all services
./scripts/start-all-services.sh start

# Individual service management
./scripts/start-all-services.sh status
./scripts/start-all-services.sh stop
./scripts/start-all-services.sh restart
```

Services are also managed by LaunchAgents:
- `com.zwang.ryanhub-services` — master start script (RunAtLoad)
- `com.dispatcher.agent` — dispatcher with KeepAlive

### Book Factory Server (standalone)
```bash
cd services/bookfactory
npm install
npm run build
node server.mjs   # HTTPS :3443, HTTP :3000
```

### Dispatcher (standalone)
```bash
cd services/dispatcher
python3.13 -m venv .venv
.venv/bin/pip install -e .
.venv/bin/dispatcher start
```

## Backend Services

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Dispatcher | 8765 | WebSocket | Chat backend for AI tab |
| Food Analysis | 18790 | HTTP | Nutrition analysis bridge (calls `claude` CLI) |
| Calendar Sync | 18791 | HTTP | Google Calendar bridge (direct API + AI agent) |
| Book Factory | 3443 / 3000 | HTTPS / HTTP | Book platform API + web UI |

## Design System (MUST follow for all UI work)

### Colors (defined in `Core/Design/Theme.swift`)
- Background: dark `#0A0A0F` / light `#F5F5F7`
- Surface: dark `#1C1C2E` / light `#FFFFFF`
- SurfaceSecondary: dark `#252540` / light `#F0F0F2`
- Primary: `#6366F1` (indigo) — use `Color.hubPrimary`
- PrimaryLight: `#818CF8`
- TextPrimary: dark white / light `#1A1A1A`
- TextSecondary: dark `#9CA3AF` / light `#6B7280`
- AccentGreen: `#22C55E`, AccentRed: `#EF4444`, AccentYellow: `#F59E0B`
- Border: dark `white.opacity(0.08)` / light `black.opacity(0.06)`

Mode-adaptive colors: use `AdaptiveColors.xxx(for: colorScheme)`.
Static colors: use `Color.hubPrimary`, `Color.hubAccentGreen`, etc.
Always use `Color.hubPrimary` (not `.hubPrimary`) in `.foregroundStyle()` contexts.

### Typography
- `.hubTitle`: 28pt bold
- `.hubHeading`: 20pt semibold
- `.hubBody`: 16pt regular
- `.hubCaption`: 13pt medium

### Layout Constants (`HubLayout`)
- `standardPadding`: 16pt, `sectionSpacing`: 24pt, `itemSpacing`: 12pt
- `cardCornerRadius`: 16pt, `buttonCornerRadius`: 12pt, `buttonHeight`: 48pt

### Reusable Components
- `HubCard` — Surface card with shadow
- `HubButton` — Primary filled button (loading state support)
- `HubSecondaryButton` — Outlined button
- `HubTextField` — Styled text input (secure mode support)
- `SectionHeader` — Uppercased caption label

## Technical Requirements (iOS)
- iOS 17.0+, Swift 5.9+, SwiftUI only
- `@Observable` macro for ViewModels (NOT ObservableObject)
- `@MainActor` on ALL ViewModels
- `async/await` for networking
- NO external dependencies
- All code and comments in English
- Localization: `en.lproj` + `zh-Hans.lproj`, access via `L10n.keyName`

## Toolkit Navigation

The Toolkit tab uses a macOS-style menu bar (not NavigationStack push/pop) for switching between tools. `ToolkitHomeView` owns a `@State selectedPlugin: ToolkitPlugin?` — `nil` shows the desktop grid, non-nil renders the tool in-place below the menu bar. BookFactory is the ONLY tool NOT wrapped in NavigationStack (it manages its own internally).

## Known Issues

- Food Analysis: JSON decoder needs `keyDecodingStrategy = .convertFromSnakeCase`
- Food Analysis: `AnalyzedFoodItem.id` uses `name` — duplicate ID collision risk
- WebSocketClient: `@Observable` mutated from non-MainActor methods
- Voice messages: No playback (waveform is display-only)
- CalendarViewModel: Requires calendar-sync-server.py running on port 18791 for real data

## Agent Dispatch Rules

1. **ALWAYS verify merge after agent completes.** Cherry-pick from worktree to main, then `git diff --stat HEAD` to confirm.
2. **ALWAYS audit agent output before reporting success.** Read key files, verify logic, build + run.
3. **Give agents FULL context.** Include: exact file paths, design system rules, @Observable patterns, build command, bundle ID.
4. **Specify what NOT to do.** Common mistakes: `str | None` (needs 3.10+ compat), missing `@MainActor`, using `name` as `id`, missing `CodingKeys`.
