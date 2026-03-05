# RyanHub → Personal Super Intelligence Platform: Strategy Document

**Author**: Zhiyuan Wang + Claude
**Date**: 2026-03-02
**Status**: Strategic planning

---

## Part 1: Development Retrospective — What We Built in 6 Days

### The Numbers

- **235 commits** across 6 days (Feb 25 — Mar 2, 2026)
- **~415K+ lines of code** across iOS (36K Swift), 4 backend services (Python + Node.js), UI tests
- **1 developer** (non-developer by training) + Claude Code as AI pair programmer
- **6 major personal intelligence modules**: Bobo (behavioral sensing), BookFactory, Health, Calendar, Fluent (language learning), Parking
- **10 passive sensors** in Bobo alone: motion, health, location, screen, battery, calls, WiFi, Bluetooth, audio/diarization, photos

### Development Timeline

| Day | Commits | What Happened |
|-----|---------|---------------|
| Feb 25 | 67 | Foundation: initialized app, ported BookFactory, renamed Cortex→RyanHub, built chat with WebSocket, added Fluent, crash fixes, design system |
| Feb 26 | 24 | Chat architecture (multi→single session), SSH terminal, parking module, service manager, CLAUDE.md leadership docs |
| Feb 27 | 102 | **PEAK day**: Launched POPO/Bobo behavioral sensing (10 sensors), speaker diarization server, audio streaming, background mode, calendar integration |
| Feb 28 | 25 | POPO→Bobo rebrand, health data sync, motion episode model, timeline dedup tuning, bridge server consolidation |
| Mar 2 | 17 | PersonalContext bus, Chat↔Bobo integration, Camera Catch, motion migration v4, timeline push to bridge server |

### Why It Succeeded

#### 1. The "Hub + Spoke" Architecture Was Right from Day 1

The single most important architectural decision: **PersonalContext bus**. Every chat message gets enriched with context from ALL modules automatically. This means:
- No keyword routing needed
- The AI agent always sees the "full picture"
- Adding a new module = implement one protocol (`ToolkitDataProvider`) + register
- Context flows naturally without explicit plumbing

This was not planned upfront — it emerged organically. But once it clicked, every new feature became dramatically easier.

#### 2. Claude Code as a Force Multiplier (Not Just Code Generator)

The unique aspect of this project: **Zhiyuan is not a developer by training** (PhD in behavioral AI / multimodal sensing). Yet the system rivals what a small engineering team would build. Why?

- **Claude Code doesn't just write code — it maintains architectural coherence.** CLAUDE.md serves as a living constitution. Every agent that touches the codebase reads it first.
- **Subagent coordination** turned one person into a team. Background agents handled independent tasks in parallel (UI, backend, tests) while the coordinator managed architecture.
- **The CLAUDE.md system is itself an innovation.** It's project memory that persists across sessions, accumulates learnings, and prevents repeat mistakes. It's essentially a "brain" for the development process.

#### 3. Monorepo + Local-First Was the Killer Combo

- iOS app + all backend services in one repo = atomic commits, no version drift
- Local-first (bridge server on localhost) = zero deployment friction during development
- LaunchAgents for service management = "it just works" background services

#### 4. Rapid Iteration Without Fear

- XCUITest suite + AgenticExplorer = automated regression catching
- Single developer = no merge conflicts, no coordination overhead
- Git auto-commit after every meaningful change = never lost work
- CLAUDE.md failure lessons = mistakes documented once, never repeated

### What Failed (and What We Learned)

#### 1. Multi-Session Chat → Single Chat (Design Pivot)

**What happened**: Initially built ChatGPT-style multi-session sidebar. Abandoned after 1 day.

**Lesson**: For a *personal* AI, you don't need separate conversations. Your life is one continuous context. The multi-session model is for generic chatbots; a personal AI should feel like an always-there companion with full memory.

#### 2. WebView Fluent → Native Fluent (Tech Pivot)

**What happened**: Initially embedded Fluent PWA in WKWebView. Performance was poor, state management messy.

**Lesson**: When a module is core to the experience, native > embedded web. Saved time initially but created tech debt. The rewrite was worth it.

#### 3. Direct Claude API → Bridge Server (Architecture Evolution)

**What happened**: Started calling Claude API directly from iOS. Migrated to local bridge server pattern.

**Lesson**: The bridge server pattern is essential — it decouples the iOS app from any specific AI provider, enables server-side tool use, and keeps API keys off the device.

#### 4. Motion Data Model Iterations (v1→v2→v3→v4)

**What happened**: Motion events started as point-in-time, evolved to episode-based with duration, required 4 migration passes to clean up.

**Lesson**: Behavioral data modeling is HARD. Start with the richest model you can (episodes with duration, not point events). Migration is expensive.

#### 5. Worktree Agents for Build Tasks (Coordination Failure)

**What happened**: Dispatched build/install tasks to worktree agents. They failed because worktrees lack SPM cache, DerivedData, etc.

**Lesson**: Environment-dependent tasks (build, install, test) should never go to isolated worktrees. This is now documented in CLAUDE.md as a permanent rule.

#### 6. Context Explosion in Subagents (Token Overflow)

**What happened**: Gave subagents the full conversation history. Claude Code crashed (OOM).

**Lesson**: "Enough context ≠ all context." The coordinator's core skill is **distilling** what an agent needs — exact file paths, specific problems, relevant constraints. Not the entire conversation.

---

## Part 2: Vision — From RyanHub to Personal Super Intelligence (PSI) Platform

### The Core Insight

RyanHub proves that a **non-developer can build a sophisticated personal AI system** using Claude Code + the right architecture. The next step: **make this replicable for anyone.**

The vision: A platform where anyone can describe their personal needs in natural language, and an AI agent iterates to generate a robust, personalized app — complete with backend services, data pipelines, and intelligent context.

### What "Personal Super Intelligence" Actually Means

It's NOT:
- Another chatbot (Inflection Pi tried this → no business model → acqui-hired by Microsoft)
- A single-purpose AI device (Humane AI Pin, Rabbit R1 → both dead)
- An AI wrapper around existing services (Notion AI, etc.)

It IS:
- **Context-rich**: Knows your schedule, health, habits, preferences, relationships
- **Action-capable**: Can book parking, manage calendar, analyze food, generate books
- **Extensible**: New capabilities via natural language description → auto-generated modules
- **Local-first**: Your data stays on your device, AI runs locally when possible
- **Cross-ecosystem**: Works with Google, Apple, arbitrary services — not locked in

### The `/new-app` Feature Design

#### User Flow

```
User: /new-app

PSI: What kind of personal tool do you need? Describe it in 1-2 sentences.

User: I want to track my pet's health — food, vet visits, weight, and get
      reminders for medications. I have a golden retriever named Max.

PSI: Got it! A few follow-up questions:
     1. Do you want to integrate with any existing vet app or service?
     2. Should it pull data from any device (like a smart pet feeder)?
     3. Do you want AI-powered health insights (e.g., "Max's weight trend
        suggests reducing portions")?

User: No existing apps. No smart feeder. Yes to AI insights.

PSI: Great. Here's what I'll build:

     📱 PetHealth Module
     ├── Weight tracker with trend chart
     ├── Food log (brand, amount, time)
     ├── Vet visit records with documents
     ├── Medication schedule with reminders
     ├── AI health insights (powered by your pet's data)
     └── Context injection → your PSI chat agent will know about Max

     Building now... [progress bar]

     ✅ PetHealth module installed! You can find it in your Toolkit.
     Your chat agent now knows about Max and can answer pet health questions.
```

#### Technical Architecture for `/new-app`

```
/new-app command
    ↓
1. Intent Extraction
   - Parse user's natural language description
   - Identify: data types, actions, integrations, AI needs
    ↓
2. Clarification Loop
   - Generate follow-up questions for ambiguity
   - Confirm scope and features
    ↓
3. Module Generation
   - Generate Swift code following design system (HubCard, HubButton, etc.)
   - Generate ViewModel with @Observable + @MainActor
   - Generate data models + persistence
   - Generate ToolkitDataProvider for context injection
   - Generate bridge server endpoints if backend needed
    ↓
4. Integration
   - Register in ToolkitPlugin enum
   - Add to PersonalContext.providers
   - Generate accessibility IDs
   - Build + verify
    ↓
5. Deployment
   - Hot-reload into running app (or rebuild + install)
   - Confirm with user
```

#### What Makes This Technically Feasible

RyanHub already has all the building blocks:

1. **Standardized design system** (Theme.swift, HubCard, HubButton, etc.) — generated code looks native
2. **ToolkitDataProvider protocol** — one interface to integrate any module
3. **PersonalContext bus** — automatic context enrichment
4. **Bridge server pattern** — extensible backend without touching iOS app
5. **CLAUDE.md** — the "constitution" that ensures generated code follows all conventions
6. **XCUITest framework** — can auto-test generated modules

The gap: making the generation **reliable and general-purpose** (not just for one user's setup).

---

## Part 3: Making It Generalizable — The Open Platform

### Current State: "Works on My Machine"

Today, RyanHub runs on Zhiyuan's iMac with:
- macOS with Python 3.13, Node.js, specific port assignments
- Claude CLI installed with API key
- Google Calendar OAuth configured
- ParkMobile cron job set up
- etc.

### Target State: "Works for Anyone in < 10 Minutes"

#### Minimal Setup for a New User

| Step | What | Time |
|------|------|------|
| 1 | Install PSI Desktop app (macOS/Linux/Windows) | 2 min |
| 2 | Install PSI Mobile app (iOS/Android) | 2 min |
| 3 | Connect AI provider (Claude API key, or local model) | 1 min |
| 4 | Authorize services (Google, Apple Health, etc.) via OAuth | 3 min |
| 5 | Describe your first module via `/new-app` | 2 min |

#### Technical Requirements for Generalizability

1. **Replace hardcoded services with MCP servers**
   - Calendar → standard MCP calendar server
   - Health → HealthKit MCP server (or Google Fit MCP)
   - File access → MCP filesystem server
   - Any new integration → discover from MCP registry (5,800+ servers available)

2. **Replace Claude CLI dependency with model-agnostic layer**
   - Support: Claude API, OpenAI API, local models (Ollama, llama.cpp)
   - MCP handles tool use across all providers
   - User chooses their preferred AI provider

3. **Containerize backend services**
   - Docker Compose for all services (bridge server, dispatcher, etc.)
   - Or: single binary with embedded services (Go/Rust)
   - Target: `docker compose up` and you're running

4. **Cross-platform mobile**
   - Current: iOS only (SwiftUI)
   - Option A: Keep iOS native + add Android (Kotlin Compose) — best UX, 2x work
   - Option B: Cross-platform (React Native / Flutter) — wider reach, lower quality
   - Option C: PWA — lowest barrier, works everywhere, limited native API access
   - **Recommended**: Start with PWA for maximum reach, add native apps later for premium tier

5. **Module marketplace**
   - Users can share modules they've created
   - Curated marketplace with quality standards
   - Revenue share with module creators

### Proposed Architecture

```
┌─────────────────────────────────────────────────┐
│                    PSI Platform                    │
│                                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  Mobile   │  │ Desktop  │  │  Web (PWA)   │   │
│  │  App      │  │  App     │  │              │   │
│  └────┬──────┘  └────┬─────┘  └──────┬───────┘   │
│       │              │               │            │
│       └──────────────┼───────────────┘            │
│                      │                             │
│              ┌───────▼────────┐                    │
│              │  PSI Core      │                    │
│              │  (local daemon) │                    │
│              │                 │                    │
│              │  - PersonalContext Bus              │
│              │  - Module Manager                   │
│              │  - MCP Client (tool routing)        │
│              │  - AI Provider Abstraction          │
│              │  - Data Store (local-first)         │
│              │  - Event Bus                        │
│              └───────┬────────┘                    │
│                      │                             │
│          ┌───────────┼───────────┐                │
│          │           │           │                │
│    ┌─────▼─────┐ ┌───▼───┐ ┌───▼────────┐       │
│    │ MCP       │ │Module │ │ AI Provider │       │
│    │ Servers   │ │Store  │ │ (Claude/    │       │
│    │ (5800+)   │ │(local)│ │  GPT/local) │       │
│    └───────────┘ └───────┘ └────────────┘       │
│                                                    │
└─────────────────────────────────────────────────┘
```

---

## Part 4: UIST Paper Strategy

### Key Intel

- **UIST 2026**: Nov 2-5, Detroit. Abstract deadline: **March 24**. Paper deadline: **March 31**.
- **Acceptance rate**: ~22% (210 papers in 2025)
- **Critical**: UIST explicitly states **"User tests are not strictly required"** — papers can use case studies, technical evaluation, demonstrations
- **Related accepted work**: Semantic Commit (AI memory at scale), Sensible Agent (proactive AR agents), ComPeer (conversational agents), PrISM-Observer (smartwatch agents)

### Paper Framing Options

#### Option A: "Personal AI Agent Platform" Systems Paper (Recommended)

**Title idea**: "PSI: A Personal Super Intelligence Platform for End-User Customizable AI Agent Ecosystems"

**Research contribution** (not just engineering):
1. **PersonalContext Bus architecture** — how passive sensing + active tools + chat context can be unified through a single protocol
2. **CLAUDE.md as persistent agent memory** — a novel pattern for maintaining development coherence across AI-assisted sessions
3. **End-user module generation** — the `/new-app` paradigm where non-developers describe needs → AI generates complete modules
4. **Evaluation**: Case studies showing 6 real modules built and used daily + technical evaluation of context integration quality

**Why UIST would care**: This sits at the intersection of:
- End-user programming (long UIST tradition)
- AI agents (hot topic, 5+ papers in 2024-2025)
- Personal informatics (health, behavior tracking)
- Toolkit design (extensible architecture)

**Evaluation approach** (no formal user study needed):
- **Case study**: 6 modules built and deployed, used daily for weeks
- **Technical evaluation**: Latency of context injection, accuracy of AI responses with vs. without PersonalContext
- **Generalizability analysis**: How many steps to create a new module? How much of the architecture is reusable?
- **Walkthrough**: Step-by-step `/new-app` demonstration

#### Option B: "Non-Developer AI-Assisted Development" Paper

**Focus**: How a non-developer used Claude Code to build a 415K-LOC system in 6 days

**Research contribution**: The CLAUDE.md system, subagent coordination patterns, failure recovery mechanisms

**Weaker because**: Less novel — "AI helps coding" is well-explored

#### Option C: "Behavioral Sensing + AI Agent Integration" Paper

**Focus**: Bobo's 10-sensor passive sensing pipeline feeding into an AI chat agent

**Research contribution**: The sensing → timeline → context → response pipeline, dedup/aggregation strategies

**Weaker because**: More incremental, similar to PrISM-Observer

### Recommendation: Go with Option A

- Broadest contribution
- Most novel angle (end-user customizable PSI)
- Naturally incorporates the other two angles as components
- Aligns with the platform vision

### Timeline to March 31

| Date | Milestone |
|------|-----------|
| Mar 2-5 | Implement `/new-app` prototype (even if rough) |
| Mar 5-10 | Run 2-3 `/new-app` case studies with different scenarios |
| Mar 10-15 | Technical evaluation (latency, context quality, code quality metrics) |
| Mar 15-20 | Paper writing: intro, system design, case studies |
| Mar 20-24 | **Abstract submission** (March 24 deadline) |
| Mar 24-31 | Complete paper, figures, polish |
| Mar 31 | **Paper submission** |

### Critical Questions for UIST

1. Does the `/new-app` capability need to actually work end-to-end, or can it be a "Wizard of Oz" demo?
   → For UIST systems paper, it should work, but can be rough
2. Do we need any user evaluation at all?
   → UIST says no, but 2-3 informal walkthroughs would strengthen it significantly
3. Is the code going to be open-sourced?
   → UIST values open-source artifacts; open-sourcing strengthens the paper

---

## Part 5: Business Strategy

### Market Landscape Summary

| Player | Status | Model |
|--------|--------|-------|
| Humane AI Pin | Dead ($116M fire sale to HP) | Hardware + subscription → failed |
| Rabbit R1 | Dying (95% user abandonment) | Hardware → failed |
| Limitless/Rewind | Acquired by Meta ($368M) | Freemium → acquired |
| Inflection Pi | Absorbed by Microsoft (~$1B) | Chatbot → no business model → acqui-hired |
| Google Gemini | 450M MAU, Personal Intelligence launched | Ecosystem lock-in |
| Apple Intelligence | Delayed, signed $1B/yr with Google Gemini | Ecosystem lock-in |
| Screenpipe | Open source, growing | Open core + premium |

### The Gap No One Has Filled

**No one has built a cross-ecosystem, local-first, extensible personal AI platform.**

- Google: only works within Google services
- Apple: AI capability far behind, locked to Apple devices
- Meta: trust issues, only Meta ecosystem
- Startups: either failed hardware bets or got acquired

### Business Model Options

#### Model 1: Open Core (Recommended for Phase 1)

```
Free (open source):
├── PSI Core (local daemon, PersonalContext bus, MCP client)
├── Basic modules (chat, calendar, notes)
├── Community module marketplace
└── Local model support

Premium ($15-29/month):
├── Cloud AI providers (Claude, GPT) with managed API keys
├── Advanced modules (behavioral sensing, health AI insights)
├── Cross-device sync
├── Priority module generation (/new-app with faster, better models)
└── Premium support
```

**Why this works**:
- Open source builds trust and community (critical for personal data product)
- Low barrier to entry → maximum user growth
- Premium features have real marginal cost (AI compute) → justifies subscription
- Module marketplace creates network effects

#### Model 2: B2B Platform (Phase 2)

Once consumer platform has traction:
- **Enterprise PSI**: Companies deploy personalized AI assistants for employees
- **White-label PSI**: Other companies build on your platform
- **Data insights** (aggregated, anonymized): Behavioral patterns → research partnerships

#### Model 3: Acquisition Target (End Goal)

**Most likely acquirers** and why:

| Acquirer | Why They'd Want PSI | What They Lack |
|----------|---------------------|----------------|
| **Apple** | Device-first personal AI that actually works | AI capability, cross-ecosystem integration |
| **Google** | Open-source alternative to their walled garden, user trust | Trust, cross-ecosystem (outside Google) |
| **Meta** | Behavioral sensing for AR glasses, personal AI for Ray-Ban | Mobile-first personal AI platform |
| **Anthropic** | Consumer surface for Claude, real-world agent deployment data | Consumer product, personal context layer |
| **Samsung** | Personal AI for Galaxy ecosystem | AI platform, sensing pipeline |

**Estimated acquisition range** (based on comparables):
- With 100K+ active users + strong tech: $50-200M
- With 1M+ active users + proven module ecosystem: $200M-1B
- Key driver: quality of personal context data pipeline + user retention

### Recommended Priority

1. **UIST paper** (March deadline) — academic credibility, forces you to articulate the research contribution
2. **Open-source the platform** (April-May) — attract developers, build community
3. **Ship MVP** (June) — `/new-app` working, 3-5 built-in modules, PWA + iOS
4. **ProductHunt launch** (July) — first wave of users
5. **Iterate on premium features** (Aug-Dec) — based on user feedback
6. **Seed funding** (if needed, Q4 2026) — armed with paper + users + open-source traction

### What NOT to Pursue

1. **Hardware** — 100% dead end. Humane, Rabbit, Limitless all proved this.
2. **Pure chatbot** — Inflection Pi proved there's no standalone business model.
3. **Enterprise-first** — You need consumer validation first. Enterprise follows.
4. **Raising money before product** — Build first, show traction, then raise.

---

## Part 6: CLAUDE.md for the Open Platform

Below is the proposed CLAUDE.md that would ship with the open-source platform, serving as both developer documentation and AI agent instructions.

```markdown
# PSI Platform — CLAUDE.md

## What is PSI?

PSI (Personal Super Intelligence) is an open platform for building personalized AI agent
ecosystems. Users describe what they need in natural language, and PSI generates complete
modules — UI, backend, data pipelines, and AI context integration.

## Architecture

### Core Components

- **PSI Core**: Local daemon managing modules, context, and AI routing
- **PersonalContext Bus**: Every AI interaction is enriched with context from ALL modules
- **Module Manager**: Installs, updates, and manages user modules
- **MCP Client**: Routes tool calls to appropriate MCP servers
- **AI Provider Abstraction**: Supports Claude, GPT, local models (Ollama, etc.)

### Module Structure

Every module follows this structure:

    my-module/
    ├── manifest.json          # Module metadata, capabilities, dependencies
    ├── context-provider.ts    # PersonalContext integration (required)
    ├── ui/                    # Frontend components
    │   ├── main-view.tsx      # Primary module view
    │   └── widgets/           # Dashboard widgets, cards
    ├── api/                   # Backend endpoints (optional)
    │   └── routes.ts
    ├── models/                # Data models
    │   └── schema.ts
    └── README.md              # Module documentation

### PersonalContext Provider (Required)

Every module MUST implement a context provider:

    export interface ContextProvider {
      // Called on every AI interaction — return relevant context summary
      buildContextSummary(): string | null;

      // Module capabilities the AI agent can invoke
      getCapabilities(): Capability[];

      // Module's data domain (e.g., "health", "calendar", "finance")
      domain: string;
    }

### Module Manifest

    {
      "name": "pet-health",
      "version": "1.0.0",
      "description": "Track your pet's health, food, vet visits, and medications",
      "domain": "pet-care",
      "author": "username",
      "capabilities": ["track", "remind", "analyze"],
      "dependencies": {
        "mcp-servers": ["calendar"],  // Optional MCP dependencies
        "ai-features": ["analysis"]   // Requires AI provider
      },
      "platforms": ["web", "ios", "android"],
      "privacy": {
        "data-local-only": true,       // Data never leaves device
        "ai-context-opt-in": true      // User must opt in to share with AI
      }
    }

## Design System

### Colors
- Primary: Indigo (#6366F1)
- Surface (dark): #1C1C2E
- Surface (light): #FFFFFF
- Background (dark): #0A0A0F
- Background (light): #F5F5F7

### Components
- Card, Button, SecondaryButton, TextField, SectionHeader
- All components auto-adapt to dark/light mode
- Use design tokens, never hardcode colors

### Typography
- Title: 28pt bold
- Heading: 20pt semibold
- Body: 16pt regular
- Caption: 13pt regular

## Privacy Principles

1. **Local-first**: All personal data stored on-device by default
2. **Opt-in sharing**: User explicitly approves what context goes to AI
3. **No telemetry**: Zero tracking, zero analytics unless user opts in
4. **Portable**: User can export ALL their data at any time
5. **Deletable**: User can delete ALL their data instantly

## AI Agent Rules

1. Always check PersonalContext before responding — the user's modules contain relevant context
2. Never fabricate data — if a module doesn't have data, say so
3. Respect module privacy settings — don't access modules the user hasn't authorized
4. Use MCP tools for actions — don't try to bypass the tool system
5. Keep responses concise and actionable

## Creating a New Module (/new-app)

The /new-app command guides users through module creation:

1. **Describe**: User describes what they need in 1-2 sentences
2. **Clarify**: AI asks 2-3 follow-up questions
3. **Design**: AI presents module architecture for approval
4. **Generate**: AI generates all files following this CLAUDE.md
5. **Verify**: Auto-test generated module
6. **Install**: Register in module manager + PersonalContext bus

### Generation Rules
- Generated code MUST follow the design system
- Generated code MUST implement ContextProvider
- Generated code MUST include manifest.json with privacy settings
- Generated code MUST NOT hardcode API keys or credentials
- Generated code MUST handle offline gracefully
```

---

## Part 7: Immediate Next Steps

### This Week (Mar 2-8)

1. **Clean up RyanHub repo** — remove personal data, hardcoded paths, API keys
2. **Create new public repo** (e.g., `psi-platform`) — fork from RyanHub with generalizable structure
3. **Implement `/new-app` prototype** — even rough, need it for UIST demo
4. **Start UIST abstract** — due March 24

### This Month (March)

5. **Run 3 `/new-app` case studies** — pet health, expense tracking, workout planner
6. **Technical evaluation** — measure context quality, generation success rate
7. **Submit UIST paper** — March 31 deadline
8. **Write architectural docs** — for open-source contributors

### Q2 2026

9. **Open-source release** — with documentation, examples, contribution guide
10. **PWA version** — cross-platform access
11. **MCP-based module system** — replace hardcoded integrations
12. **ProductHunt launch**
