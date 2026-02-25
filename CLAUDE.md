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

## Technical Requirements
- iOS 17.0+, Swift 5.9+, SwiftUI only
- `@Observable` macro for ViewModels
- `async/await` for networking
- NO external dependencies
- All code and comments in English
- Localization: `en.lproj` + `zh-Hans.lproj`, access via `L10n.keyName`
