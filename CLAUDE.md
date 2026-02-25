# Cortex — Personal Assistant iOS App

## Overview

Cortex is a unified personal assistant iOS app built with SwiftUI. It combines an AI chat interface (connected to a Python Dispatcher via WebSocket), a toolkit of personal tools, and a settings panel — all in a single native iOS application.

## Architecture

```
CortexApp/
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
    │   ├── Fluent/             # Language learning
    │   ├── Parking/            # ParkMobile management
    │   ├── Calendar/           # Schedule & events
    │   └── Health/             # Wellness & fitness tracking
    └── Settings/               # Server config, appearance, language, about
```

## Design System (MUST follow for all UI work)

### Colors (defined in `Core/Design/Theme.swift`)
- `.cortexBackground`: dark `#0A0A0F` / light `#F5F5F7`
- `.cortexSurface`: dark `#1C1C2E` / light `#FFFFFF`
- `.cortexSurfaceSecondary`: dark `#252540` / light `#F0F0F2`
- `.cortexPrimary`: `#6366F1` (indigo, both modes) — use `Color.cortexPrimary` (not `.cortexPrimary`) in `.foregroundStyle()` to avoid ShapeStyle inference issues
- `.cortexPrimaryLight`: `#818CF8`
- `.cortexTextPrimary`: dark white / light `#1A1A1A`
- `.cortexTextSecondary`: dark `#9CA3AF` / light `#6B7280`
- `.cortexAccentGreen`: `#22C55E`
- `.cortexAccentRed`: `#EF4444`
- `.cortexAccentYellow`: `#F59E0B`
- `.cortexBorder`: dark `white.opacity(0.08)` / light `black.opacity(0.06)`

**Important:** Colors that adapt to dark/light mode use `AdaptiveColors.xxx(for: colorScheme)`. Static colors (cortexPrimary, accent colors) are `Color.cortexXxx`. Always use `Color.cortexPrimary` explicitly when used in `.foregroundStyle()` contexts.

### Typography
- `.cortexTitle`: 28pt bold
- `.cortexHeading`: 20pt semibold
- `.cortexBody`: 16pt regular
- `.cortexCaption`: 13pt medium

### Layout Constants (`CortexLayout`)
- `standardPadding`: 16pt
- `cardInnerPadding`: 16pt
- `sectionSpacing`: 24pt
- `itemSpacing`: 12pt
- `cardCornerRadius`: 16pt
- `buttonCornerRadius`: 12pt
- `inputCornerRadius`: 12pt
- `buttonHeight`: 48pt

### Reusable Components
- `CortexCard` — Surface card with shadow
- `CortexButton` — Primary filled button (supports loading state)
- `CortexSecondaryButton` — Outlined button
- `CortexTextField` — Styled text input (supports secure mode)
- `SectionHeader` — Uppercased caption label

## WebSocket Protocol

Connects to a Python Dispatcher at a configurable URL (default: `ws://localhost:8765`).

```json
// Client -> Server
{"type": "message", "id": "uuid", "content": "user text", "project": null}

// Server -> Client (streaming response)
{"type": "response", "id": "uuid", "content": "partial...", "streaming": true}
{"type": "response", "id": "uuid", "content": "final text", "streaming": false}

// Server -> Client (status)
{"type": "status", "connected": true, "active_sessions": 0}

// Server -> Client (error)
{"type": "error", "id": "uuid", "message": "error description"}
```

## Build Instructions

```bash
# Generate Xcode project
cd /Users/zwang/projects/cortex-app
xcodegen generate

# Build for simulator
xcodebuild -scheme CortexApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Open in Xcode
open CortexApp.xcodeproj
```

## Technical Requirements
- iOS 17.0+ deployment target
- Swift 5.9+
- SwiftUI only (no UIKit unless absolutely necessary)
- `@Observable` macro for ViewModels (not `ObservableObject`)
- `async/await` for all networking
- **NO external dependencies** — native URLSession, URLSessionWebSocketTask only
- All code, comments, and documentation in **English**

## Localization
- Strings defined in `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`
- Access via `L10n.keyName` (see `LocalizationManager.swift`)
- Add new keys to both files when adding UI strings

## Agent Contribution Guidelines

1. **Follow the design system exactly** — use the provided colors, fonts, and components
2. **Use `AdaptiveColors.xxx(for: colorScheme)` for mode-adaptive colors** — add `@Environment(\.colorScheme) private var colorScheme` to your views
3. **Use `Color.cortexPrimary` (not `.cortexPrimary`)** in `.foregroundStyle()` contexts to avoid Swift type inference errors
4. **Use `@Observable` (not `ObservableObject`)** for view models
5. **Keep all code in English** — comments, variable names, documentation
6. **No external packages** — use native iOS APIs only
7. **Run `xcodegen generate` after adding new files** to update the Xcode project
8. **Test builds with**: `xcodebuild -scheme CortexApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
9. **AppState is shared globally** via `@Environment(AppState.self)` — use it for cross-module state (server URL, appearance, language)
10. **Toolkit plugins** should be self-contained within their `Modules/Toolkit/<PluginName>/` directory
