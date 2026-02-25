# Ryan Hub — Personal Assistant iOS App

## Overview

Ryan Hub is a unified personal assistant iOS app built with SwiftUI. It combines an AI chat interface (connected to a Python Dispatcher via WebSocket), a toolkit of personal tools, and a settings panel — all in a single native iOS application.

The Dispatcher lives in a separate project (`/Users/zwang/projects/cortex/packages/dispatcher/`) and provides the WebSocket backend for chat.

## Architecture

```
RyanHub/
├── App/                        # Entry point, root TabView
├── Core/
│   ├── Design/                 # Theme (colors, fonts, layout) + reusable components
│   ├── Networking/             # WebSocketClient, APIClient (native URLSession only)
│   ├── Localization/           # L10n manager + en/zh-Hans .strings files
│   └── Models/                 # AppState (global observable state)
└── Modules/
    ├── Chat/                   # AI chat interface (Views, ViewModels, Models)
    ├── Toolkit/                # Personal tools grid + plugin modules
    │   ├── BookFactory/        # Book generation & audio playback
    │   ├── Fluent/             # Language learning (WebView wrapper for PWA)
    │   ├── Parking/            # ParkMobile management
    │   ├── Calendar/           # Schedule & events
    │   └── Health/             # Wellness & fitness tracking
    └── Settings/               # Server config, appearance, language, about
```

## Relationship to Other Projects

- **Dispatcher** (`cortex/packages/dispatcher/`): Provides WebSocket backend for Chat tab. NOT part of this repo.
- **Book Factory** (`bookfactory/server/`): Provides API backend for the Book Factory plugin. iOS code lives HERE in RyanHub, not in the bookfactory repo (that iOS code is archived).
- **Fluent** (`fluent/`): PWA deployed on Vercel. RyanHub just wraps it in a WebView.
- **Parking** (`parkmobile-auto/`): Commands sent via Dispatcher chat. No direct API dependency.

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
- `standardPadding`: 16pt
- `sectionSpacing`: 24pt
- `itemSpacing`: 12pt
- `cardCornerRadius`: 16pt
- `buttonCornerRadius`: 12pt
- `buttonHeight`: 48pt

### Reusable Components
- `HubCard` — Surface card with shadow
- `HubButton` — Primary filled button (loading state support)
- `HubSecondaryButton` — Outlined button
- `HubTextField` — Styled text input (secure mode support)
- `SectionHeader` — Uppercased caption label

## Build Instructions

```bash
cd /Users/zwang/projects/cortex-app
xcodegen generate
xcodebuild -scheme RyanHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
open RyanHub.xcodeproj
```

## Backend Services

The app depends on three local services. All managed by a unified LaunchAgent:

| Service | Port | Start Command |
|---------|------|---------------|
| Dispatcher (WebSocket) | 8765 | `cd /Users/zwang/projects/cortex/packages/dispatcher && node dist/index.js` |
| Food Analysis Bridge | 18790 | `python3 scripts/food-analysis-server.py` (calls `claude` CLI) |
| Book Factory Server | 3443 | `cd /Users/zwang/projects/bookfactory/server && node dist/index.js` |

Master script: `scripts/start-all-services.sh [start|stop|status|restart]`
LaunchAgent: `com.zwang.ryanhub-services` (runs at login)

## Technical Requirements
- iOS 17.0+, Swift 5.9+, SwiftUI only
- `@Observable` macro for ViewModels
- `async/await` for networking
- NO external dependencies
- All code and comments in English
- Localization: `en.lproj` + `zh-Hans.lproj`, access via `L10n.keyName`

## Toolkit Navigation

The Toolkit tab uses a macOS-style menu bar (not NavigationStack push/pop) for switching between tools. `ToolkitHomeView` owns a `@State selectedPlugin: ToolkitPlugin?` — `nil` shows the desktop grid, non-nil renders the tool in-place below the menu bar. BookFactory is the ONLY tool NOT wrapped in NavigationStack (it manages its own internally).

## Agent Dispatch Playbook (Lessons Learned 2026-02-25)

### Critical Rules for Dispatching Sub-Agents

1. **ALWAYS verify merge after agent completes.** Cherry-pick from worktree to main, then `git diff --stat HEAD` to confirm changes landed. Don't trust `git log` alone — the commit may be on a worktree branch, not main.

2. **ALWAYS audit agent output before reporting success.** Read key files the agent changed, verify logic, build + run. Agents can claim "BUILD SUCCEEDED" while producing subtly broken code.

3. **Give agents FULL context.** Agents start with zero knowledge. Every dispatch must include:
   - Exact file paths to read first
   - Design system rules (AdaptiveColors, HubLayout, Color.hubPrimary)
   - @Observable patterns (NOT ObservableObject)
   - Known crash patterns (sheets don't inherit @Observable env; navigationDestination needs explicit .environment())
   - Build command with -project flag
   - Bundle ID: `com.zwang.ryanhub.RyanHub`

4. **Specify what NOT to do.** Common agent mistakes:
   - Using `str | None` Python syntax (needs 3.9 compat)
   - Using `@MainActor` inconsistently — should be on ALL ViewModels
   - Using `name` as Identifiable `id` instead of UUID (causes SwiftUI duplicate ID bugs)
   - Not adding `CodingKeys` or `keyDecodingStrategy` for JSON from LLM output (Claude may return snake_case randomly)
   - Adding NotificationCenter observers without removeObserver in deinit
   - Hardcoding "/5" for max reconnect attempts instead of reading from constant

5. **Track worktree → main merge status.** After each agent completes:
   ```
   ✅ Agent done → Audit code → Cherry-pick/copy to main → Build → Install → Verify → Push
   ```

### Known Issues Backlog (from audits)

**High Priority:**
- [x] Chat: User messages disappear — FIXED: Dispatcher echoes same ID back; user+assistant shared SwiftUI identity. Added `resp-` prefix to assistant IDs.
- [ ] Food Analysis: JSON decoder needs `keyDecodingStrategy = .convertFromSnakeCase` (Claude Haiku may return snake_case)
- [ ] Food Analysis: `AnalyzedFoodItem.id` uses `name` — duplicate ID collision risk
- [x] FluentView: NotificationCenter observers never removed — FIXED: Rebuilt Fluent as fully native SwiftUI (no more WebView/WKWebView)

**Medium Priority:**
- [x] ChatViewModel: Missing `@MainActor` annotation — FIXED: Added @MainActor to ChatViewModel
- [ ] WebSocketClient: `@Observable` mutated from non-MainActor methods
- [ ] Voice messages: No playback (waveform is display-only)
- [ ] ParkingViewModel: `date(bySetting:)` can cross month boundaries
- [ ] CalendarViewModel: `syncEvents()` marks complete but events stay empty (no real backend integration yet)

**Low Priority:**
- [ ] Parking weekday headers: ambiguous single letters (T/T, S/S)
- [ ] Calendar: DateFormatter created on every computed property access
- [ ] Recording waveform: choppy 100ms discrete updates
- [ ] Stale CortexApp.xcodeproj should be removed
- [ ] Connection status strings duplicate between ChatView and SettingsView
