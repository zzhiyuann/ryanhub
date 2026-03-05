#!/usr/bin/env python3
"""
Dynamic Module Generator v2 for RyanHub — Agent-Driven Pipeline

Generates sophisticated, multi-view toolkit modules using a phased agent pipeline:
  Phase 1: Deep Planning (Opus) — analyze real needs, market apps, design architecture
  Phase 2: Sequential Code Generation (Sonnet) — 8-12 files, cascading context
  Phase 3: Build + Auto-Fix (max 3 retries)
  Phase 4: Quality Gate — verify multi-view, rich ViewModel, proper controls

Usage:
  python3 scripts/generate-module.py --description "Track daily water intake with goals"
  python3 scripts/generate-module.py --batch scenarios.json
  python3 scripts/generate-module.py --list
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap

RYANHUB_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DYNAMIC_MODULES_DIR = os.path.join(
    RYANHUB_ROOT, "RyanHub", "Modules", "Toolkit", "DynamicModules"
)
BOOTSTRAP_FILE = os.path.join(DYNAMIC_MODULES_DIR, "DynamicModuleBootstrap.swift")
CLAUDE_PATH = shutil.which("claude") or os.path.expanduser("~/.local/bin/claude")

# Filter env to prevent Claude nesting error
CLEAN_ENV = {k: v for k, v in os.environ.items() if k not in ("CLAUDE_CODE", "CLAUDECODE")}

# Available icon colors
ICON_COLORS = ["hubPrimary", "hubPrimaryLight", "hubAccentGreen", "hubAccentRed", "hubAccentYellow"]

# ─────────────────────────────────────────────────────────────────────
# Shared component signatures for prompts
# ─────────────────────────────────────────────────────────────────────
SHARED_COMPONENTS_DOC = """
SHARED REUSABLE COMPONENTS (already exist, import SwiftUI + Charts to use):

1. ModuleChartView — Line/area/bar chart via Swift Charts
   ModuleChartView(
       title: String,
       subtitle: String? = nil,
       dataPoints: [ChartDataPoint],   // ChartDataPoint(label: String, value: Double)
       style: ChartStyle = .line,       // .line or .bar
       color: Color = .hubPrimary,
       showArea: Bool = true
   )

2. ProgressRingView — Circular goal progress indicator
   ProgressRingView(
       progress: Double,    // 0.0 to 1.0
       current: String,     // center display value
       unit: String = "",
       goal: String? = nil, // "of 8 glasses"
       color: Color = .hubPrimary,
       size: CGFloat = 120,
       lineWidth: CGFloat = 10
   )
   CompactProgressRing(progress: Double, color: Color = .hubPrimary, size: CGFloat = 24)

3. StatCard — Metric + trend indicator in a card
   StatCard(
       title: String,
       value: String,
       icon: String = "chart.bar.fill",
       trend: StatTrend? = nil,
       color: Color = .hubPrimary
   )
   StatTrend.from(change: Double, format: String = "%.1f", invertPositive: Bool = false)
   StatGrid { StatCard(...) StatCard(...) }  // 2-column grid layout

4. StreakCounter — Current/longest streak with flame
   StreakCounter(
       currentStreak: Int,
       longestStreak: Int,
       unit: String = "days",
       isActiveToday: Bool = false
   )

5. CalendarHeatmap — GitHub-style activity grid
   CalendarHeatmap(
       title: String = "Activity",
       data: [Date: Double],   // date -> intensity value
       color: Color = .hubPrimary,
       weeks: Int = 12
   )

6. QuickEntrySheet — Modal sheet for data entry
   QuickEntrySheet(
       title: String,
       icon: String = "plus.circle.fill",
       saveLabel: String = "Save",
       canSave: Bool = true,
       onSave: @escaping () -> Void
   ) { content views }
   EntryFormSection(title: String) { content }
   QuickEntryFAB(action: { ... })   // Floating action button

7. InsightCard — AI/computed insight display
   InsightCard(insight: ModuleInsight)
   ModuleInsight(type: .trend/.achievement/.suggestion/.warning, title: String, message: String)
   InsightsList(insights: [ModuleInsight])
"""

DESIGN_SYSTEM_DOC = """
RYAN HUB DESIGN SYSTEM (must follow exactly):

Colors:
  - Color.hubPrimary (#6366F1 indigo), Color.hubPrimaryLight, Color.hubAccentGreen, Color.hubAccentRed, Color.hubAccentYellow
  - AdaptiveColors.textPrimary(for: colorScheme), .textSecondary(for:), .background(for:), .surface(for:), .surfaceSecondary(for:), .border(for:)

Typography:
  - .hubTitle (28pt bold), .hubHeading (20pt semibold), .hubBody (16pt regular), .hubCaption (13pt medium)

Layout:
  - HubLayout.standardPadding (16), .sectionSpacing (24), .itemSpacing (12), .cardCornerRadius (16), .buttonCornerRadius (12), .buttonHeight (48)

Components:
  - HubCard { content }  — trailing closure ViewBuilder, no params
  - HubButton("Label") { action }  — positional title
  - HubTextField(placeholder: "Label", text: $binding)  — requires placeholder: label
  - SectionHeader(title: "Label")  — requires title: label

Patterns:
  - @Environment(\\.colorScheme) private var colorScheme on every view
  - @Observable @MainActor on ViewModels (NOT ObservableObject)
  - async/await for all networking
  - SwiftUI only, no UIKit
"""

VM_ARCHITECTURE_DOC = """
VIEWMODEL ARCHITECTURE for dynamic modules:

The ViewModel manages data via bridge server REST API:
  - GET  /modules/<moduleId>/data — returns [Entry] array
  - POST /modules/<moduleId>/data/add — add entry (JSON body)
  - DELETE /modules/<moduleId>/data?id=<entryId> — delete entry

Required structure:
  @Observable @MainActor
  final class <Name>ViewModel {
      var entries: [<Name>Entry] = []
      var isLoading = false
      var errorMessage: String?

      // Bridge server URL
      private var bridgeBaseURL: String {
          UserDefaults.standard.string(forKey: "ryanhub_server_url")
              .flatMap { URL(string: $0)?.host }
              .map { "http://\\($0):18790" }
              ?? "http://localhost:18790"
      }

      init() { Task { await loadData() } }

      func loadData() async { ... }      // GET entries
      func addEntry(_ entry: ...) async { ... }  // POST entry
      func deleteEntry(_ entry: ...) async { ... }  // DELETE entry

      // RICH COMPUTED PROPERTIES — this is where sophistication lives:
      // - todayEntries, weekEntries, monthEntries (date-filtered)
      // - streak calculations (current streak, longest streak)
      // - trend analysis (this week vs last week)
      // - chart data (transform entries to [ChartDataPoint])
      // - goal progress (progress toward daily/weekly targets)
      // - insights (computed [ModuleInsight] array)
      // - averages, totals, distributions
  }

After loading data, cache for DataProvider:
  UserDefaults.standard.set(data, forKey: "dynamic_module_<moduleId>_cache")
"""


# ─────────────────────────────────────────────────────────────────────
# Claude API
# ─────────────────────────────────────────────────────────────────────

def call_claude(prompt: str, model: str = "sonnet", max_tokens: int = 16000,
                timeout: int = 300, disable_tools: bool = False) -> str:
    """Call Claude CLI. Returns response text.
    Set disable_tools=True for pure code generation (prevents Claude from using
    Write/Edit tools and forces it to output code as text)."""
    env = dict(CLEAN_ENV)
    env["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] = str(max_tokens)
    cmd = [CLAUDE_PATH, "--print", "--model", model]
    if disable_tools:
        cmd.extend(["--tools", ""])
    # Write prompt to temp file to avoid shell arg length issues with large prompts
    prompt_file = os.path.join(RYANHUB_ROOT, "scripts", "debug", ".prompt_tmp.txt")
    os.makedirs(os.path.dirname(prompt_file), exist_ok=True)
    with open(prompt_file, "w") as f:
        f.write(prompt)
    cmd.extend(["-p", prompt])
    try:
        result = subprocess.run(
            cmd,
            capture_output=True, text=True, timeout=timeout, env=env,
        )
    except subprocess.TimeoutExpired:
        print(f"  [TIMEOUT] Claude call timed out after {timeout}s")
        return ""
    if result.returncode != 0:
        print(f"  [ERROR] Claude call failed: {result.stderr[:500]}")
        return ""
    return result.stdout.strip()


def extract_json(text: str) -> dict:
    """Extract JSON object from text, handling markdown fences."""
    # Try to find JSON block
    json_match = re.search(r"```(?:json)?\s*\n([\s\S]*?)\n```", text)
    if json_match:
        return json.loads(json_match.group(1))
    # Try raw JSON
    json_match = re.search(r"\{[\s\S]*\}", text)
    if json_match:
        return json.loads(json_match.group())
    raise ValueError(f"No JSON found in response:\n{text[:500]}")


def extract_swift(text: str) -> str:
    """Extract Swift code from response, stripping markdown fences and preamble."""
    # Remove all markdown fences
    code = re.sub(r"```swift\s*\n?", "", text)
    code = re.sub(r"```\s*", "", code)
    # Find the best starting point: prefer 'import SwiftUI' that's followed by a struct/class
    # This handles cases where Claude prepends a ViewModel summary before the actual View code
    best_idx = -1
    search_from = 0
    while True:
        idx = code.find("import SwiftUI", search_from)
        if idx < 0:
            break
        # Check if this import is followed by a struct...View or meaningful code
        after = code[idx:idx + 500]
        if "struct " in after and "View" in after:
            best_idx = idx
            break
        if best_idx < 0:
            best_idx = idx  # fallback to first import SwiftUI
        search_from = idx + 1
    if best_idx >= 0:
        code = code[best_idx:]
    else:
        # Fall back to any import statement
        idx = code.find("import ")
        if idx >= 0:
            code = code[idx:]
    return code.strip()


def summarize_swift_code(code: str) -> str:
    """Extract struct/class/enum signatures + computed property signatures from Swift code.
    Returns a condensed version suitable for prompt context."""
    lines = code.split("\n")
    result = []
    in_body = False
    brace_depth = 0
    for line in lines:
        stripped = line.strip()
        # Always include struct/class/enum/protocol declarations
        if re.match(r"(struct|class|enum|protocol)\s+\w+", stripped):
            result.append(line)
            in_body = True
            brace_depth = 0
        # Include property/method signatures at top level of type
        elif in_body and brace_depth <= 1:
            if re.match(r"(var|let|func|case|static)\s+", stripped):
                # For computed properties, just show signature
                if "{" in stripped and "}" not in stripped:
                    result.append(line.split("{")[0].rstrip() + " { ... }")
                else:
                    result.append(line)
        # Track brace depth
        brace_depth += stripped.count("{") - stripped.count("}")
        if brace_depth <= 0:
            in_body = False
    return "\n".join(result)


def extract_vm_public_api(vm_code: str) -> str:
    """Extract a strict public API contract from ViewModel code.
    Returns a clear listing of every public property name, type, and method signature
    that Views are allowed to use. Much more reliable than summarize_swift_code()."""
    lines = vm_code.split("\n")
    properties = []
    methods = []
    in_class = False
    brace_depth = 0

    for line in lines:
        stripped = line.strip()

        # Track class start
        if re.match(r"(final\s+)?class\s+\w+ViewModel", stripped):
            in_class = True
            brace_depth = 0

        if not in_class:
            brace_depth += stripped.count("{") - stripped.count("}")
            continue

        # Only look at top-level members (brace_depth == 1)
        brace_depth += stripped.count("{") - stripped.count("}")

        # Skip private/fileprivate members
        if "private " in stripped or "fileprivate " in stripped:
            continue

        # Detect stored properties: var name: Type = default
        stored_match = re.match(r"var\s+(\w+)\s*:\s*(.+?)\s*=", stripped)
        if stored_match and brace_depth <= 2:
            pname, ptype = stored_match.groups()
            ptype = ptype.strip().rstrip("{")
            properties.append(f"  var {pname}: {ptype}  // stored")
            continue

        # Detect computed properties: var name: Type {
        computed_match = re.match(r"var\s+(\w+)\s*:\s*(.+?)\s*\{", stripped)
        if computed_match and brace_depth <= 2:
            pname, ptype = computed_match.groups()
            ptype = ptype.strip()
            properties.append(f"  var {pname}: {ptype}  // computed")
            continue

        # Detect methods: func name(...) async? ...
        func_match = re.match(r"func\s+(\w+)\s*\(([^)]*)\)(.*?)(?:\{|$)", stripped)
        if func_match and brace_depth <= 2:
            fname, params, rest = func_match.groups()
            is_async = "async" in rest
            async_str = " async" if is_async else ""
            methods.append(f"  func {fname}({params}){async_str}")
            continue

        # Track class end
        if brace_depth <= 0:
            in_class = False

    result = "VIEWMODEL PUBLIC API CONTRACT — Views MUST ONLY use these exact names:\n\n"
    result += "PROPERTIES:\n"
    result += "\n".join(properties) if properties else "  (none found)"
    result += "\n\nMETHODS (async methods MUST be wrapped in Task { await ... }):\n"
    result += "\n".join(methods) if methods else "  (none found)"
    result += "\n\nRULES:\n"
    result += "- If a property is not listed above, it does NOT exist — do not invent names\n"
    result += "- Use exact property names as shown (e.g., if it says 'currentStreak', do NOT use 'streak')\n"
    result += "- All async methods (addEntry, deleteEntry, loadData) MUST be called inside Task { await ... }\n"
    return result


# ─────────────────────────────────────────────────────────────────────
# Phase 1: Deep Planning (Opus)
# ─────────────────────────────────────────────────────────────────────

def phase1_deep_planning(description: str) -> dict:
    """Use Opus to deeply analyze the need and design module architecture."""
    print("[Phase 1] Deep planning with Opus...")

    prompt = f"""You are an expert iOS app designer and Swift developer.

A user wants a personal tracker module: "{description}"

Your job is to DEEPLY THINK about this — not just the literal request, but:
1. What does the user ACTUALLY need? What problems are they solving?
2. What do premium apps in this category do? (Think: top-rated App Store apps)
3. What analytics, insights, and visualizations would make this genuinely useful?
4. What gamification elements drive retention? (Streaks, goals, achievements)

Design a RICH, MULTI-VIEW module with sophisticated domain intelligence.

Return a JSON object with this EXACT structure:

{{
  "moduleId": "camelCase identifier",
  "moduleName": "PascalCase (for Swift types)",
  "displayName": "Human-readable name",
  "shortName": "1-2 word menu label",
  "subtitle": "Brief tagline for card display",
  "icon": "SF Symbol name (must be a real SF Symbol)",
  "iconColor": "one of: {ICON_COLORS}",
  "relevanceKeywords": ["5-10 lowercase keywords for AI context matching"],

  "dataFields": [
    {{"name": "fieldName", "type": "SwiftType", "label": "Human Label", "control": "stepper|slider|picker|toggle|text|datePicker"}},
    ...
  ],

  "enums": [
    {{"name": "EnumName", "cases": [{{"name": "caseName", "displayName": "Display", "icon": "sf.symbol"}}]}}
  ],

  "views": [
    {{"name": "DashboardView", "purpose": "Main dashboard with stats, progress ring, and quick-add", "components": ["StatGrid", "ProgressRingView", "QuickEntryFAB"]}},
    {{"name": "EntrySheet", "purpose": "Quick entry modal with domain-appropriate controls", "components": ["QuickEntrySheet", "EntryFormSection"]}},
    {{"name": "HistoryView", "purpose": "Date-grouped entry list with filtering", "components": ["CalendarHeatmap"]}},
    {{"name": "AnalyticsView", "purpose": "Charts, trends, and insights", "components": ["ModuleChartView", "InsightsList"]}}
  ],

  "viewModelComputedProperties": [
    {{"name": "propertyName", "type": "ReturnType", "description": "What it computes"}},
    ...
  ],

  "domainLogic": {{
    "dailyGoal": {{"description": "...", "defaultValue": "..."}},
    "streakDefinition": "What counts as an active day",
    "trendAnalysis": "What trends to track (e.g., weekly average vs previous week)",
    "insights": ["List of computed insight types"]
  }}
}}

RULES:
- dataFields: DO NOT include "id" or "date" — those are auto-added by the system
- dataFields: Each field MUST have a "control" specifying the input type:
  - "stepper" for integer counts (glasses, cups, sets)
  - "slider" for ratings (1-10 scale, quality 1-5)
  - "picker" for enums/categories (use with corresponding enum)
  - "toggle" for booleans
  - "text" ONLY for free-text fields (notes, descriptions, names)
  - "datePicker" for time selection
- NEVER use "text" control for numbers, booleans, dates, or enum categories
- Include at least 3-4 views (dashboard, entry, history, analytics)
- Include 8+ viewModelComputedProperties (today stats, weekly stats, streak, trend, chart data, goal progress, insights)
- enums: Define proper Swift enums for any category/type fields (with displayName and icon)
- domainLogic: Be specific — real formulas, real insight descriptions

Return ONLY valid JSON. No markdown fences. No explanation.
"""
    response = call_claude(prompt, model="opus", max_tokens=8000, timeout=300, disable_tools=True)
    spec = extract_json(response)

    # Validate minimum quality
    if len(spec.get("views", [])) < 3:
        print("  [WARN] Opus returned fewer than 3 views, adding defaults")
        if not any(v["name"].endswith("View") and "Dashboard" in v["name"] for v in spec.get("views", [])):
            spec.setdefault("views", []).append({
                "name": "DashboardView",
                "purpose": "Main dashboard with key stats",
                "components": ["StatGrid", "ProgressRingView"]
            })

    if len(spec.get("viewModelComputedProperties", [])) < 5:
        print("  [WARN] Fewer than 5 computed properties, adding defaults")
        defaults = [
            {"name": "todayEntries", "type": "[Entry]", "description": "Entries from today"},
            {"name": "currentStreak", "type": "Int", "description": "Current consecutive active days"},
            {"name": "longestStreak", "type": "Int", "description": "Longest ever streak"},
            {"name": "weeklyChartData", "type": "[ChartDataPoint]", "description": "Chart data for past 7 days"},
            {"name": "insights", "type": "[ModuleInsight]", "description": "Computed insights array"},
        ]
        existing = {p["name"] for p in spec.get("viewModelComputedProperties", [])}
        for d in defaults:
            if d["name"] not in existing:
                spec.setdefault("viewModelComputedProperties", []).append(d)

    print(f"  Module: {spec['moduleName']} ({spec['moduleId']})")
    print(f"  Views: {len(spec.get('views', []))}")
    print(f"  Computed properties: {len(spec.get('viewModelComputedProperties', []))}")
    print(f"  Enums: {len(spec.get('enums', []))}")
    return spec


# ─────────────────────────────────────────────────────────────────────
# Phase 2: Sequential Code Generation (Sonnet)
# ─────────────────────────────────────────────────────────────────────

def phase2_generate_code(spec: dict) -> dict[str, str]:
    """Generate all module files: Models + ViewModel via agent, then ALL views in one call."""
    name = spec["moduleName"]
    module_id = spec["moduleId"]
    print(f"\n[Phase 2] Generating code for {name}...")

    generated_files: dict[str, str] = {}

    # 2a. Models
    print("  [2a] Generating Models...")
    models_code = generate_models_v2(spec)
    generated_files[f"{name}Models.swift"] = models_code

    # 2b. ViewModel
    print("  [2b] Generating ViewModel...")
    vm_code = generate_viewmodel_v2(spec, generated_files)
    generated_files[f"{name}ViewModel.swift"] = vm_code

    # 2c. ALL views + root view in ONE call (avoids per-view timeout)
    print("  [2c] Generating all views (single call)...")
    view_files = generate_all_views(spec, generated_files)
    generated_files.update(view_files)

    # 2d. DataProvider (template)
    print("  [2d] Generating DataProvider...")
    dp_code = generate_data_provider(spec)
    generated_files[f"{name}DataProvider.swift"] = dp_code

    # 2e. Registration (template)
    print("  [2e] Generating Registration...")
    reg_code = generate_registration(spec)
    generated_files[f"{name}Registration.swift"] = reg_code

    print(f"  Total files: {len(generated_files)}")
    return generated_files


def generate_models_v2(spec: dict) -> str:
    """Generate rich models with enums, computed properties, proper types."""
    name = spec["moduleName"]
    fields = [f for f in spec["dataFields"] if f["name"] not in ("id", "date")]
    enums = spec.get("enums", [])

    prompt = f"""Generate a Swift models file for a module called "{name}".

MODULE SPEC:
{json.dumps(spec, indent=2)}

REQUIREMENTS:
1. Main entry struct: `{name}Entry: Codable, Identifiable`
   - MUST have: `var id: String = UUID().uuidString`
   - MUST have: `var date: String = {{ let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: Date()) }}()`
   - Add all dataFields as properties (use proper Swift types)
   - Add rich computed properties: formattedDate, summaryLine, and domain-specific ones

2. Enums: Generate CaseIterable, Codable, Identifiable enums with:
   - `var id: String {{ rawValue }}`
   - `var displayName: String` (switch)
   - `var icon: String` (SF Symbol, switch)
   - Each enum from the spec

3. Add any helper computed properties that views/ViewModel will need.

IMPORTANT: Do NOT define `InsightItem`, `ModuleInsight`, `ChartDataPoint`, `StatTrend`, or any type
that already exists in the shared components. These are provided by the app's design system.
Only define types specific to this module.

{DESIGN_SYSTEM_DOC}

Return ONLY Swift code. No markdown fences. Start with `import Foundation`.
"""
    code = call_claude(prompt, max_tokens=8000, disable_tools=True)
    code = extract_swift(code)
    if not code.strip().startswith("import"):
        return generate_models_fallback(spec)
    return code


def generate_models_fallback(spec: dict) -> str:
    """Fallback template for models if agent fails."""
    name = spec["moduleName"]
    fields = [f for f in spec["dataFields"] if f["name"] not in ("id", "date")]
    enums = spec.get("enums", [])

    lines = ["import Foundation", "", f"// MARK: - {name} Models", ""]

    # Enums first
    for enum_spec in enums:
        ename = enum_spec["name"]
        lines.append(f"enum {ename}: String, Codable, CaseIterable, Identifiable {{")
        for case_spec in enum_spec["cases"]:
            lines.append(f'    case {case_spec["name"]}')
        lines.append(f"    var id: String {{ rawValue }}")
        lines.append(f"    var displayName: String {{")
        lines.append(f"        switch self {{")
        for case_spec in enum_spec["cases"]:
            lines.append(f'        case .{case_spec["name"]}: return "{case_spec["displayName"]}"')
        lines.append(f"        }}")
        lines.append(f"    }}")
        lines.append(f"    var icon: String {{")
        lines.append(f"        switch self {{")
        for case_spec in enum_spec["cases"]:
            icon = case_spec.get("icon", "circle.fill")
            lines.append(f'        case .{case_spec["name"]}: return "{icon}"')
        lines.append(f"        }}")
        lines.append(f"    }}")
        lines.append("}")
        lines.append("")

    # Main entry struct
    lines.append(f"struct {name}Entry: Codable, Identifiable {{")
    lines.append(f"    var id: String = UUID().uuidString")
    lines.append(f"    var date: String = {{")
    lines.append(f'        let f = DateFormatter()')
    lines.append(f'        f.dateFormat = "yyyy-MM-dd HH:mm"')
    lines.append(f'        return f.string(from: Date())')
    lines.append(f"    }}()")
    for f in fields:
        lines.append(f"    var {f['name']}: {f['type']}")
    lines.append("")
    lines.append("    var summaryLine: String {")
    lines.append("        var parts: [String] = [date]")
    for f in fields:
        if f["name"] == "note":
            continue
        if f["type"].endswith("?"):
            lines.append(f'        if let v = {f["name"]} {{ parts.append("\\(v)") }}')
        else:
            lines.append(f'        parts.append("\\({f["name"]})")')
    lines.append('        return parts.joined(separator: " | ")')
    lines.append("    }")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def generate_viewmodel_v2(spec: dict, prior_files: dict[str, str]) -> str:
    """Generate a rich ViewModel with 8+ computed properties."""
    name = spec["moduleName"]
    module_id = spec["moduleId"]

    # Include the models code so the agent knows exact types
    models_code = list(prior_files.values())[0] if prior_files else ""

    prompt = f"""Generate a Swift ViewModel for a module called "{name}".

MODELS CODE (already generated — use these exact types):
```swift
{models_code}
```

MODULE SPEC:
{json.dumps({k: spec[k] for k in ["moduleName", "moduleId", "displayName", "viewModelComputedProperties", "domainLogic", "dataFields"]}, indent=2)}

{VM_ARCHITECTURE_DOC}

REQUIRED COMPUTED PROPERTIES (implement ALL of these):
{json.dumps(spec.get("viewModelComputedProperties", []), indent=2)}

DOMAIN LOGIC:
{json.dumps(spec.get("domainLogic", {}), indent=2)}

ADDITIONAL REQUIREMENTS:
1. Bridge server CRUD (loadData, addEntry, deleteEntry) — same pattern as docs above
2. Implement EVERY computed property from the spec
3. Streak calculation: count consecutive days with entries, working backwards from today
4. Chart data: transform entries into [ChartDataPoint] for ModuleChartView
5. Insights: return [ModuleInsight] based on patterns (trends, achievements, suggestions)
6. Date helpers: todayEntries, weekEntries, use Calendar.current.isDate(_:inSameDayAs:)
7. Cache data to UserDefaults for DataProvider context injection

{DESIGN_SYSTEM_DOC}

CRITICAL: The entry type is `{name}Entry` exactly as defined in the models code above.
For ChartDataPoint: `ChartDataPoint(label: String, value: Double)` — label is a display string.
For ModuleInsight: `ModuleInsight(type: .trend/.achievement/.suggestion/.warning, title: String, message: String)`

Return ONLY Swift code. No markdown fences. Start with `import Foundation`.
"""
    code = call_claude(prompt, max_tokens=16000, timeout=300, disable_tools=True)
    code = extract_swift(code)
    if not code.strip().startswith("import"):
        return generate_viewmodel_fallback(spec)
    return code


def generate_viewmodel_fallback(spec: dict) -> str:
    """Minimal ViewModel fallback."""
    name = spec["moduleName"]
    module_id = spec["moduleId"]
    return f'''import Foundation
import SwiftUI

// MARK: - {name} View Model

@Observable
@MainActor
final class {name}ViewModel {{
    var entries: [{name}Entry] = []
    var isLoading = false
    var errorMessage: String?

    private var bridgeBaseURL: String {{
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap {{ URL(string: $0)?.host }}
            .map {{ "http://\\($0):18790" }}
            ?? "http://localhost:18790"
    }}

    init() {{ Task {{ await loadData() }} }}

    // MARK: - Computed Properties

    var todayEntries: [{name}Entry] {{
        let today = DateFormatter()
        today.dateFormat = "yyyy-MM-dd"
        let todayStr = today.string(from: Date())
        return entries.filter {{ $0.date.hasPrefix(todayStr) }}
    }}

    var currentStreak: Int {{
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let entryDates = Set(entries.compactMap {{ df.date(from: String($0.date.prefix(10))) }}.map {{ calendar.startOfDay(for: $0) }})
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while entryDates.contains(day) {{
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }}
        return streak
    }}

    var longestStreak: Int {{
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let sortedDates = entries.compactMap {{ df.date(from: String($0.date.prefix(10))) }}
            .map {{ calendar.startOfDay(for: $0) }}
        let unique = Array(Set(sortedDates)).sorted()
        guard !unique.isEmpty else {{ return 0 }}
        var longest = 1, current = 1
        for i in 1..<unique.count {{
            if calendar.dateComponents([.day], from: unique[i-1], to: unique[i]).day == 1 {{
                current += 1
                longest = max(longest, current)
            }} else {{
                current = 1
            }}
        }}
        return longest
    }}

    var weeklyChartData: [ChartDataPoint] {{
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "E"
        var result: [ChartDataPoint] = []
        for dayOffset in (0..<7).reversed() {{
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayStr = df.string(from: day)
            let count = entries.filter {{ $0.date.hasPrefix(dayStr) }}.count
            result.append(ChartDataPoint(label: displayFmt.string(from: day), value: Double(count)))
        }}
        return result
    }}

    var insights: [ModuleInsight] {{
        var result: [ModuleInsight] = []
        if currentStreak >= 3 {{
            result.append(ModuleInsight(type: .achievement, title: "\\(currentStreak)-Day Streak!", message: "You've been consistent for \\(currentStreak) days. Keep it up!"))
        }}
        if todayEntries.isEmpty {{
            result.append(ModuleInsight(type: .suggestion, title: "No entries today", message: "Don't forget to log your data for today."))
        }}
        return result
    }}

    // MARK: - CRUD

    func loadData() async {{
        isLoading = true
        defer {{ isLoading = false }}
        do {{
            let url = URL(string: "\\(bridgeBaseURL)/modules/{module_id}/data")!
            let (data, _) = try await URLSession.shared.data(from: url)
            entries = try JSONDecoder().decode([{name}Entry].self, from: data)
            UserDefaults.standard.set(data, forKey: "dynamic_module_{module_id}_cache")
        }} catch {{
            entries = []
        }}
    }}

    func addEntry(_ entry: {name}Entry) async {{
        do {{
            let url = URL(string: "\\(bridgeBaseURL)/modules/{module_id}/data/add")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        }} catch {{
            errorMessage = "Failed to add entry"
        }}
    }}

    func deleteEntry(_ entry: {name}Entry) async {{
        do {{
            let url = URL(string: "\\(bridgeBaseURL)/modules/{module_id}/data?id=\\(entry.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        }} catch {{
            errorMessage = "Failed to delete entry"
        }}
    }}
}}
'''


def _generate_single_view(name: str, display_name: str, view_role: str, view_name: str,
                           models_code: str, vm_code: str, spec: dict,
                           extra_context: str = "") -> str:
    """Generate a single view file via Claude. Returns Swift code or empty string on failure."""
    vm_api_contract = extract_vm_public_api(vm_code)

    role_instructions = {
        "dashboard": f"""Generate {name}{view_name}.swift — a rich Dashboard view.
- StatGrid with 4 StatCards using REAL ViewModel computed properties (scan the ViewModel summary below!)
- ProgressRingView if ViewModel has progress/goal properties
- StreakCounter if ViewModel has streak properties (use ACTUAL property names from ViewModel!)
- Recent entries section showing todayEntries (or equivalent) with summaryLine, date, and delete button
- Make the layout feel unique to {display_name} — what would a premium {display_name} app show on its home screen?""",

        "entry": f"""Generate {name}{view_name}.swift — a data entry sheet.
- Use QuickEntrySheet(title: "Add {display_name}", icon: "plus.circle.fill", canSave: true, onSave: {{ }}) {{ content }}
- Use EntryFormSection(title:) for each field group
- Check the ViewModel's addEntry() method signature — does it take an Entry struct or individual params? Match it EXACTLY.
- Use Stepper for Int counts, Slider for 1-10 ratings, Picker for enums, Toggle for bools, DatePicker for dates
- NEVER use TextField for numbers, booleans, or enum categories
- Include `var onSave: (() -> Void)?` property, call onSave?() after save""",

        "history": f"""Generate {name}{view_name}.swift — a history/log view.
- CalendarHeatmap(title: "Activity", data: viewModel.calendarData, color: .hubPrimary) at top if ViewModel has calendarData
- Entries grouped by date sections, newest first, each in HubCard with delete button
- Show entry.summaryLine and entry.date (or formattedDate)
- Empty state when no entries: VStack with icon and "No entries yet" text""",

        "analytics": f"""Generate {name}{view_name}.swift — an analytics view.
- ModuleChartView with the ACTUAL chart data property from ViewModel (check the summary: chartData? weeklyChartData? weeklyData?)
- If ViewModel has insights as [String], use ForEach with Text in HubCard
- If ViewModel has insights as [ModuleInsight], use InsightsList(insights: viewModel.insights)
- Domain-specific summary stats in HubCard — highlight what makes this {display_name} tracker unique
- Show total count, current streak, best streak etc using ACTUAL ViewModel property names""",
    }

    instruction = role_instructions.get(view_role, role_instructions["dashboard"])

    prompt = f"""Generate ONE SwiftUI view file for a RyanHub module.

{instruction}

{vm_api_contract}

FULL VIEWMODEL CODE (reference for exact property names and types):
```swift
{vm_code}
```

MODELS (use these exact types):
```swift
{models_code}
```

{extra_context}

DESIGN RULES:
- @Environment(\\.colorScheme) private var colorScheme
- `let viewModel: {name}ViewModel` (not @State, not @Bindable — it's passed from parent)
- Use Color.hubPrimary, Color.hubAccentGreen, Color.hubAccentRed, Color.hubAccentYellow (always prefix with Color.)
- Use AdaptiveColors.textPrimary(for: colorScheme), AdaptiveColors.textSecondary(for: colorScheme)
- Use AdaptiveColors.background(for: colorScheme) for ScrollView background
- Use .hubTitle, .hubHeading, .hubBody, .hubCaption for fonts
- Use HubLayout.standardPadding, HubLayout.sectionSpacing, HubLayout.itemSpacing
- Use HubCard {{ content }} for card containers
- Do NOT import Charts (ModuleChartView handles it internally)
- StatCard(title: String, value: String, icon: String, color: Color)
- StatGrid {{ content }} wraps StatCards in a 2x2 grid
- SectionHeader(title: "Label") — requires title: argument label
- HubTextField(placeholder: "Label", text: $binding) — requires placeholder: argument label
- Button actions that call async methods: Button {{ Task {{ await viewModel.deleteEntry(entry) }} }} label: {{ ... }}

IMPORTANT: Your entire output will be saved directly as a .swift file.
Do NOT write any explanation, description, or commentary.
Do NOT use markdown fences (```).
Your very first line of output must be: import SwiftUI
"""
    for attempt in range(3):
        if attempt > 0:
            print(f"      Retry {attempt} for {view_role}...")
        response = call_claude(prompt, model="sonnet", max_tokens=8000, timeout=300, disable_tools=True)
        if not response:
            print(f"      Claude returned empty for {view_role} (attempt {attempt+1})")
            continue
        code = extract_swift(response)
        if code and code.strip().startswith("import"):
            return code
        print(f"      Claude returned {len(response)} chars but no Swift code (attempt {attempt+1})")
        # Save debug
        debug_dir = os.path.join(RYANHUB_ROOT, "scripts", "debug")
        os.makedirs(debug_dir, exist_ok=True)
        with open(os.path.join(debug_dir, f"{name}_{view_role}_fail_{attempt}.txt"), "w") as f:
            f.write(response)
    return ""


def generate_all_views(spec: dict, prior_files: dict[str, str]) -> dict[str, str]:
    """Generate all views via individual Claude calls with template fallback."""
    name = spec["moduleName"]
    display_name = spec["displayName"]
    icon = spec["icon"]
    views = spec.get("views", [])
    fields = [f for f in spec.get("dataFields", []) if f["name"] not in ("id", "date")]
    enums = spec.get("enums", [])
    domain = spec.get("domainLogic", {})

    models_code = prior_files.get(f"{name}Models.swift", "")
    vm_code = prior_files.get(f"{name}ViewModel.swift", "")

    # Classify views by role
    sheet_view_name = None
    for v in views:
        if "Sheet" in v["name"] or "Entry" in v["name"]:
            sheet_view_name = v["name"]
    if not sheet_view_name:
        sheet_view_name = "EntrySheet"

    dashboard_name = next((v["name"] for v in views if "Dashboard" in v["name"]), "DashboardView")
    history_name = next((v["name"] for v in views if "History" in v["name"] or "Log" in v["name"]), "HistoryView")
    analytics_name = next((v["name"] for v in views if "Analytics" in v["name"] or "Stats" in v["name"]), "AnalyticsView")

    # Shared components doc for extra context
    extra_ctx = SHARED_COMPONENTS_DOC

    result = {}
    view_tasks = [
        (dashboard_name, "dashboard", _gen_dashboard_view, (spec, fields, enums, domain)),
        (sheet_view_name, "entry", _gen_entry_sheet, (spec, fields, enums)),
        (history_name, "history", _gen_history_view, (spec, fields)),
        (analytics_name, "analytics", _gen_analytics_view, (spec,)),
    ]

    for view_name, role, fallback_fn, fallback_args in view_tasks:
        fname = f"{name}{view_name}.swift"
        print(f"    Generating {fname} via Claude...")
        code = _generate_single_view(name, display_name, role, view_name,
                                     models_code, vm_code, spec, extra_ctx)
        if code:
            n_lines = code.count("\n") + 1
            print(f"    OK: {fname} ({n_lines} lines, Claude-generated)")
            result[fname] = code
        else:
            print(f"    [FALLBACK] {fname} — using template")
            result[fname] = fallback_fn(*fallback_args)

    # Root view (always template — it's mechanical)
    tab_labels = [dashboard_name, history_name, analytics_name]
    result[f"{name}View.swift"] = _gen_root_view(spec, tab_labels, sheet_view_name)
    print(f"    Generated {name}View.swift (root, template)")

    return result


def _build_view_generation_prompt(spec, name, display_name, icon, models_code, vm_code,
                                   views, dashboard_name, sheet_view_name,
                                   history_name, analytics_name, tab_labels):
    """Build the prompt for Claude to generate domain-specific views."""
    view_specs_json = json.dumps(views, indent=2)
    return f"""Generate ALL SwiftUI view files for a RyanHub module "{name}" ("{display_name}").

ACTUAL MODELS (use these exact types):
```swift
{models_code}
```

ACTUAL VIEWMODEL (ONLY use properties/methods defined here — read carefully):
```swift
{vm_code}
```

{extract_vm_public_api(vm_code)}

VIEW SPEC:
{view_specs_json}

{SHARED_COMPONENTS_DOC}

{DESIGN_SYSTEM_DOC}

GENERATE 5 FILES — each UNIQUE to this domain, not cookie-cutter:

1. {name}{dashboard_name}.swift — Dashboard
   - StatGrid with 4 StatCards using REAL ViewModel computed properties
   - ProgressRingView if ViewModel has progress/goal properties
   - StreakCounter if ViewModel has streak properties (use ACTUAL property names!)
   - Recent entries section with delete buttons
   - Make the layout feel domain-specific — what would a premium {display_name} app show?

2. {name}{sheet_view_name}.swift — Entry form
   - QuickEntrySheet(title: "Add {display_name}", icon: "plus.circle.fill", canSave: true, onSave: {{ }}) {{ content }}
   - EntryFormSection(title:) for each field group
   - Match ViewModel.addEntry() signature EXACTLY — check if it takes Entry struct or individual params
   - Stepper for Int counts, Slider for 1-10 ratings, Picker for enums, Toggle for bools, DatePicker for dates
   - NEVER use TextField for numbers, booleans, or categories
   - Include `var onSave: (() -> Void)?` property, call onSave?() after save

3. {name}{history_name}.swift — History
   - CalendarHeatmap(title: "Activity", data: [Date: Double], color: .hubPrimary) at top
   - Entries grouped by date, newest first, each in HubCard with delete
   - Empty state when no entries

4. {name}{analytics_name}.swift — Analytics
   - ModuleChartView with the ACTUAL chart data property from ViewModel
   - Insights section: if [String] use ForEach with Text in HubCard; if [ModuleInsight] use InsightsList
   - Domain-specific summary stats — highlight what makes this tracker unique

5. {name}View.swift — Root view
   - @State private var viewModel = {name}ViewModel()
   - @State private var selectedTab = 0
   - @State private var showAddSheet = false
   - Header: Circle with icon + "{display_name}" text
   - Picker tabs: {json.dumps(tab_labels)}
   - ZStack with tab content views + QuickEntryFAB {{ showAddSheet = true }}
   - .task {{ await viewModel.loadData() }}
   - .sheet(isPresented: $showAddSheet) {{ {name}{sheet_view_name}(viewModel: viewModel) {{ showAddSheet = false }} }}

ABSOLUTE RULES:
- ONLY reference properties/methods that EXIST in the ViewModel code above. Scan it line by line.
- If ViewModel has `chartData` not `weeklyChartData`, use `chartData`
- If ViewModel has `careStreak` not `currentStreak`, use `careStreak`
- Private ViewModel properties are NOT accessible — only use non-private var/func
- Every view: @Environment(\.colorScheme) private var colorScheme
- Sub-views: `let viewModel: {name}ViewModel` (not @State, not @Bindable)
- ScrollView body: .background(AdaptiveColors.background(for: colorScheme))
- Do NOT import Charts — ModuleChartView handles it internally
- ALL async method calls (addEntry, deleteEntry, loadData) MUST be wrapped: Task {{ await viewModel.method(...) }}
- HubTextField(placeholder: "Label", text: $binding) — requires placeholder: argument label
- SectionHeader(title: "Label") — requires title: argument label
- Always use Color.hubPrimary, Color.hubAccentGreen etc. (with Color. prefix) in .foregroundStyle()

OUTPUT FORMAT — separate each file with this exact pattern:
--- FileName.swift ---
import SwiftUI
...complete compilable code...
--- NextFile.swift ---
import SwiftUI
...

No markdown fences around code. No explanation text. Just the separator lines and Swift code.
"""


def _gen_dashboard_view(spec: dict, fields: list, enums: list, domain: dict) -> str:
    """Generate a rich dashboard with ProgressRing, StatCards, StreakCounter, recent entries."""
    name = spec["moduleName"]
    display_name = spec["displayName"]
    icon = spec["icon"]

    # Determine the primary numeric field for the progress ring
    numeric_fields = [f for f in fields if f["type"] in ("Int", "Double") and f["name"] != "note"]
    primary_field = numeric_fields[0] if numeric_fields else None

    # Build progress ring / summary section
    progress_section = f'''
                // Summary Card
                HubCard {{
                    HStack {{
                        VStack(alignment: .leading, spacing: 4) {{
                            Text("\\(viewModel.todayEntries.count)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Text("Today's entries")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }}
                        Spacer()
                        Text("\\(viewModel.entries.count) total")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }}
                }}
'''

    # Build stat cards — use safe computed properties from fallback VM
    stat_cards = f'''
                // Stats
                StatGrid {{
                    StatCard(
                        title: "Today",
                        value: "\\(viewModel.todayEntries.count)",
                        icon: "{icon}",
                        color: .hubPrimary
                    )
                    StatCard(
                        title: "Streak",
                        value: "\\(viewModel.currentStreak)d",
                        icon: "flame.fill",
                        color: .hubAccentYellow
                    )
                    StatCard(
                        title: "Best",
                        value: "\\(viewModel.longestStreak)d",
                        icon: "trophy.fill",
                        color: .hubAccentGreen
                    )
                    StatCard(
                        title: "Total",
                        value: "\\(viewModel.entries.count)",
                        icon: "chart.bar.fill",
                        color: .hubPrimaryLight
                    )
                }}
'''

    # Build recent entries section
    first_display_field = next((f for f in fields if f["name"] != "note" and not f["type"].endswith("?")), None)
    entry_display = 'Text(entry.summaryLine).font(.hubBody).foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))'

    return f'''import SwiftUI

struct {name}DashboardView: View {{
    @Environment(\\.colorScheme) private var colorScheme
    let viewModel: {name}ViewModel

    var body: some View {{
        ScrollView {{
            VStack(spacing: HubLayout.sectionSpacing) {{
{progress_section}
{stat_cards}

                // Streak
                StreakCounter(
                    currentStreak: viewModel.currentStreak,
                    longestStreak: viewModel.longestStreak,
                    isActiveToday: !viewModel.todayEntries.isEmpty
                )

                // Recent Entries
                if !viewModel.todayEntries.isEmpty {{
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {{
                        SectionHeader(title: "Today")
                        ForEach(viewModel.todayEntries.reversed()) {{ entry in
                            HubCard {{
                                HStack {{
                                    VStack(alignment: .leading, spacing: 4) {{
                                        {entry_display}
                                        Text(entry.date)
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    }}
                                    Spacer()
                                    Button {{
                                        Task {{ await viewModel.deleteEntry(entry) }}
                                    }} label: {{
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.hubAccentRed)
                                    }}
                                }}
                            }}
                        }}
                    }}
                }}
            }}
            .padding(HubLayout.standardPadding)
        }}
        .background(AdaptiveColors.background(for: colorScheme))
    }}
}}
'''


def _gen_entry_sheet(spec: dict, fields: list, enums: list) -> str:
    """Generate a QuickEntrySheet with domain-appropriate controls."""
    name = spec["moduleName"]
    display_name = spec["displayName"]

    # Build @State declarations and input controls
    state_vars = []
    form_controls = []
    entry_init_args = []

    enum_names = {e["name"] for e in enums}

    for f in fields:
        fname = f["name"]
        ftype = f["type"]
        label = f["label"]
        control = f.get("control", "text")
        is_optional = ftype.endswith("?")
        base_type = ftype.rstrip("?")

        if base_type in enum_names:
            # Enum picker
            state_vars.append(f"    @State private var selected{fname.capitalize()}: {base_type} = .{enums[next(i for i, e in enumerate(enums) if e['name'] == base_type)]['cases'][0]['name']}")
            form_controls.append(f'''
                EntryFormSection(title: "{label}") {{
                    Picker("{label}", selection: $selected{fname.capitalize()}) {{
                        ForEach({base_type}.allCases) {{ item in
                            Label(item.displayName, systemImage: item.icon).tag(item)
                        }}
                    }}
                    .pickerStyle(.menu)
                }}''')
            entry_init_args.append(f"{fname}: selected{fname.capitalize()}")

        elif control == "stepper" or (base_type == "Int" and control != "slider"):
            default = "0" if is_optional else "1"
            state_vars.append(f"    @State private var input{fname.capitalize()}: Int = {default}")
            form_controls.append(f'''
                EntryFormSection(title: "{label}") {{
                    Stepper("\\(input{fname.capitalize()}) {label.lower()}", value: $input{fname.capitalize()}, in: 0...9999)
                }}''')
            entry_init_args.append(f"{fname}: input{fname.capitalize()}")

        elif control == "slider" or (base_type in ("Int", "Double") and "rating" in fname.lower()):
            state_vars.append(f"    @State private var input{fname.capitalize()}: Double = 5")
            form_controls.append(f'''
                EntryFormSection(title: "{label}") {{
                    VStack {{
                        HStack {{
                            Text("\\(Int(input{fname.capitalize()}))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.hubPrimary)
                            Spacer()
                        }}
                        Slider(value: $input{fname.capitalize()}, in: 1...10, step: 1)
                            .tint(Color.hubPrimary)
                    }}
                }}''')
            if base_type == "Int":
                entry_init_args.append(f"{fname}: Int(input{fname.capitalize()})")
            else:
                entry_init_args.append(f"{fname}: input{fname.capitalize()}")

        elif control == "toggle" or base_type == "Bool":
            state_vars.append(f"    @State private var input{fname.capitalize()}: Bool = false")
            form_controls.append(f'''
                EntryFormSection(title: "{label}") {{
                    Toggle("{label}", isOn: $input{fname.capitalize()})
                        .tint(Color.hubPrimary)
                }}''')
            entry_init_args.append(f"{fname}: input{fname.capitalize()}")

        elif control == "datePicker":
            state_vars.append(f"    @State private var input{fname.capitalize()}: Date = Date()")
            form_controls.append(f'''
                EntryFormSection(title: "{label}") {{
                    DatePicker("{label}", selection: $input{fname.capitalize()}, displayedComponents: .hourAndMinute)
                }}''')
            # Pass Date directly if field type is Date, otherwise format to String
            if base_type == "Date":
                entry_init_args.append(f"{fname}: input{fname.capitalize()}")
            else:
                entry_init_args.append(f'{fname}: {{ let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: input{fname.capitalize()}) }}()')

        elif base_type == "Double":
            state_vars.append(f'    @State private var input{fname.capitalize()}: String = ""')
            form_controls.append(f'''
                EntryFormSection(title: "{label}") {{
                    HubTextField(placeholder: "{label}", text: $input{fname.capitalize()})
                        .keyboardType(.decimalPad)
                }}''')
            if is_optional:
                entry_init_args.append(f"{fname}: Double(input{fname.capitalize()})")
            else:
                entry_init_args.append(f"{fname}: Double(input{fname.capitalize()}) ?? 0")

        else:
            # Text field (for actual text: notes, descriptions, names)
            state_vars.append(f'    @State private var input{fname.capitalize()}: String = ""')
            form_controls.append(f'''
                EntryFormSection(title: "{label}") {{
                    HubTextField(placeholder: "{label}", text: $input{fname.capitalize()})
                }}''')
            if is_optional:
                entry_init_args.append(f"{fname}: input{fname.capitalize()}.isEmpty ? nil : input{fname.capitalize()}")
            else:
                entry_init_args.append(f"{fname}: input{fname.capitalize()}")

    state_vars_str = "\n".join(state_vars)
    form_controls_str = "\n".join(form_controls)
    entry_args_str = ", ".join(entry_init_args)

    # Determine the sheet view name from spec
    sheet_name = "AddEntrySheet"
    for v in spec.get("views", []):
        if "Sheet" in v["name"] or "Entry" in v["name"]:
            sheet_name = v["name"]
            break

    return f'''import SwiftUI

struct {name}{sheet_name}: View {{
    @Environment(\\.colorScheme) private var colorScheme
    let viewModel: {name}ViewModel
    var onSave: (() -> Void)?
{state_vars_str}

    var body: some View {{
        QuickEntrySheet(
            title: "Add {display_name}",
            icon: "plus.circle.fill",
            canSave: true,
            onSave: {{
                let entry = {name}Entry({entry_args_str})
                Task {{ await viewModel.addEntry(entry) }}
                onSave?()
            }}
        ) {{
{form_controls_str}
        }}
    }}
}}
'''


def _gen_history_view(spec: dict, fields: list) -> str:
    """Generate a history view with CalendarHeatmap and grouped entries."""
    name = spec["moduleName"]

    # Find the history view name from spec
    history_name = "HistoryView"
    for v in spec.get("views", []):
        if "History" in v["name"]:
            history_name = v["name"]
            break

    return f'''import SwiftUI

struct {name}{history_name}: View {{
    @Environment(\\.colorScheme) private var colorScheme
    let viewModel: {name}ViewModel

    private var heatmapData: [Date: Double] {{
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var result: [Date: Double] = [:]
        for entry in viewModel.entries {{
            if let date = df.date(from: String(entry.date.prefix(10))) {{
                let day = calendar.startOfDay(for: date)
                result[day, default: 0] += 1
            }}
        }}
        return result
    }}

    private var groupedEntries: [(String, [{name}Entry])] {{
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let grouped = Dictionary(grouping: viewModel.entries) {{ String($0.date.prefix(10)) }}
        return grouped.sorted {{ $0.key > $1.key }}
    }}

    var body: some View {{
        ScrollView {{
            VStack(spacing: HubLayout.sectionSpacing) {{
                // Calendar Heatmap
                CalendarHeatmap(
                    title: "Activity",
                    data: heatmapData,
                    color: .hubPrimary
                )

                // Grouped entries by date
                ForEach(groupedEntries, id: \\.0) {{ dateStr, entries in
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {{
                        SectionHeader(title: dateStr)
                        ForEach(entries) {{ entry in
                            HubCard {{
                                HStack {{
                                    VStack(alignment: .leading, spacing: 4) {{
                                        Text(entry.summaryLine)
                                            .font(.hubBody)
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        Text(entry.date)
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    }}
                                    Spacer()
                                    Button {{
                                        Task {{ await viewModel.deleteEntry(entry) }}
                                    }} label: {{
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.hubAccentRed.opacity(0.7))
                                    }}
                                }}
                            }}
                        }}
                    }}
                }}

                if viewModel.entries.isEmpty {{
                    VStack(spacing: 12) {{
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("No entries yet")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }}
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }}
            }}
            .padding(HubLayout.standardPadding)
        }}
        .background(AdaptiveColors.background(for: colorScheme))
    }}
}}
'''


def _gen_analytics_view(spec: dict) -> str:
    """Generate an analytics view with charts and insights."""
    name = spec["moduleName"]

    analytics_name = "AnalyticsView"
    for v in spec.get("views", []):
        if "Analytics" in v["name"] or "Stats" in v["name"]:
            analytics_name = v["name"]
            break

    return f'''import SwiftUI

struct {name}{analytics_name}: View {{
    @Environment(\\.colorScheme) private var colorScheme
    let viewModel: {name}ViewModel

    var body: some View {{
        ScrollView {{
            VStack(spacing: HubLayout.sectionSpacing) {{
                // Weekly Chart
                ModuleChartView(
                    title: "This Week",
                    subtitle: "Daily entries",
                    dataPoints: viewModel.weeklyChartData,
                    style: .bar,
                    color: .hubPrimary
                )

                // Insights
                if !viewModel.insights.isEmpty {{
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {{
                        SectionHeader(title: "Insights")
                        InsightsList(insights: viewModel.insights)
                    }}
                }}

                // Stats summary
                HubCard {{
                    VStack(alignment: .leading, spacing: 12) {{
                        Text("Summary")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        HStack {{
                            VStack(alignment: .leading, spacing: 4) {{
                                Text("Total Entries")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("\\(viewModel.entries.count)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }}
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {{
                                Text("Current Streak")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("\\(viewModel.currentStreak) days")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.hubAccentYellow)
                            }}
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {{
                                Text("Best Streak")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text("\\(viewModel.longestStreak) days")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.hubAccentGreen)
                            }}
                        }}
                    }}
                }}
            }}
            .padding(HubLayout.standardPadding)
        }}
        .background(AdaptiveColors.background(for: colorScheme))
    }}
}}
'''


def _gen_root_view(spec: dict, tab_view_names: list[str], sheet_view_name: str) -> str:
    """Generate the root view with tab switching and entry sheet."""
    name = spec["moduleName"]
    display_name = spec["displayName"]
    icon = spec["icon"]

    # Build tab cases and views
    tab_labels = [vn.replace("View", "").replace("Dashboard", "Home") for vn in tab_view_names]
    tab_picker_items = ""
    tab_switch_cases = ""
    for i, (vn, label) in enumerate(zip(tab_view_names, tab_labels)):
        tab_picker_items += f'                    Text("{label}").tag({i})\n'
        tab_switch_cases += f'''                    if selectedTab == {i} {{
                        {name}{vn}(viewModel: viewModel)
                    }}
'''

    return f'''import SwiftUI

struct {name}View: View {{
    @Environment(\\.colorScheme) private var colorScheme
    @State private var viewModel = {name}ViewModel()
    @State private var selectedTab = 0
    @State private var showAddSheet = false

    var body: some View {{
        VStack(spacing: 0) {{
            // Header
            HStack(spacing: 12) {{
                ZStack {{
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "{icon}")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }}
                Text("{display_name}")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }}
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {{
{tab_picker_items}            }}
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.itemSpacing)

            // Content
            ZStack(alignment: .bottomTrailing) {{
{tab_switch_cases}
                // FAB
                QuickEntryFAB {{
                    showAddSheet = true
                }}
                .padding(HubLayout.standardPadding)
            }}
        }}
        .background(AdaptiveColors.background(for: colorScheme))
        .task {{ await viewModel.loadData() }}
        .sheet(isPresented: $showAddSheet) {{
            {name}{sheet_view_name}(viewModel: viewModel) {{
                showAddSheet = false
            }}
        }}
    }}
}}
'''


def generate_root_view_fallback(spec: dict, view_structs: list[str]) -> str:
    """Minimal root view fallback."""
    name = spec["moduleName"]
    display_name = spec["displayName"]
    icon = spec["icon"]

    tab_cases = ""
    tab_views = ""
    for i, vs in enumerate(view_structs):
        label = vs.replace(name, "").replace("View", "").replace("Sheet", "")
        if "Sheet" in vs or "Entry" in vs:
            continue  # Skip entry sheets from tabs
        tab_cases += f'                Text("{label}").tag({i})\n'
        tab_views += f"""
                if selectedTab == {i} {{
                    {vs}(viewModel: viewModel)
                }}
"""

    return f'''import SwiftUI

struct {name}View: View {{
    @Environment(\\.colorScheme) private var colorScheme
    @State private var viewModel = {name}ViewModel()
    @State private var selectedTab = 0
    @State private var showAddSheet = false

    var body: some View {{
        VStack(spacing: 0) {{
            // Header
            HStack(spacing: 12) {{
                ZStack {{
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "{icon}")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }}
                Text("{display_name}")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }}
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {{
{tab_cases}            }}
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.itemSpacing)

            // Content
            ZStack(alignment: .bottomTrailing) {{
{tab_views}
                QuickEntryFAB {{
                    showAddSheet = true
                }}
                .padding(HubLayout.standardPadding)
            }}
        }}
        .background(AdaptiveColors.background(for: colorScheme))
        .task {{ await viewModel.loadData() }}
        .sheet(isPresented: $showAddSheet) {{
            Text("Add Entry")
        }}
    }}
}}
'''


def generate_data_provider(spec: dict) -> str:
    """Generate DataProvider (template, same as v1 but cleaner)."""
    name = spec["moduleName"]
    module_id = spec["moduleId"]
    display_name = spec["displayName"]
    keywords = spec.get("relevanceKeywords", [])
    keywords_str = ", ".join(f'"{k}"' for k in keywords)

    return f'''import Foundation

// MARK: - {name} Data Provider

enum {name}DataProvider: ToolkitDataProvider {{
    static let toolkitId = "{module_id}"
    static let displayName = "{display_name}"
    static let relevanceKeywords: [String] = [{keywords_str}]

    private static var bridgeBaseURL: String {{
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap {{ URL(string: $0)?.host }}
            .map {{ "http://\\($0):18790" }}
            ?? "http://localhost:18790"
    }}

    static func buildContextSummary() -> String? {{
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_{module_id}_cache"),
              let entries = try? JSONDecoder().decode([{name}Entry].self, from: data),
              !entries.isEmpty else {{
            return nil
        }}

        var lines: [String] = ["[\\(displayName)]"]
        lines.append("Total entries: \\(entries.count)")
        let recent = entries.suffix(5)
        for entry in recent {{
            lines.append("  - \\(entry.summaryLine)")
        }}
        lines.append("Actions:")
        lines.append("  - Add: POST http://localhost:18790/modules/{module_id}/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/{module_id}/data")
        lines.append("[End \\(displayName)]")
        return lines.joined(separator: "\\n")
    }}
}}
'''


def generate_registration(spec: dict) -> str:
    """Generate Registration file (template)."""
    name = spec["moduleName"]
    module_id = spec["moduleId"]
    display_name = spec["displayName"]
    short_name = spec["shortName"]
    subtitle = spec["subtitle"]
    icon = spec["icon"]
    icon_color = spec.get("iconColor", "hubPrimary")

    return f'''import SwiftUI

// MARK: - {name} Registration

extension DynamicModuleRegistry {{
    static func register{name}() {{
        shared.register(DynamicModuleDescriptor(
            id: "{module_id}",
            toolkitId: "{module_id}",
            displayName: "{display_name}",
            shortName: "{short_name}",
            subtitle: "{subtitle}",
            icon: "{icon}",
            iconColorName: "{icon_color}",
            viewBuilder: {{ AnyView({name}View()) }},
            dataProviderType: {name}DataProvider.self
        ))
    }}
}}
'''


# ─────────────────────────────────────────────────────────────────────
# Phase 2.5: Deterministic Auto-Fixes (runs before build)
# ─────────────────────────────────────────────────────────────────────

def deterministic_fixes(module_dir: str, vm_code: str) -> int:
    """Apply regex-based fixes for known error patterns. Returns count of fixes applied.
    These are patterns that Claude consistently gets wrong — fix them deterministically
    instead of relying on another Claude call."""
    fix_count = 0

    # Extract public property names and async method names from ViewModel
    vm_public_props = set()
    vm_async_methods = set()
    for line in vm_code.split("\n"):
        stripped = line.strip()
        if "private " in stripped or "fileprivate " in stripped:
            continue
        # Stored/computed properties
        prop_match = re.match(r"var\s+(\w+)\s*:", stripped)
        if prop_match:
            vm_public_props.add(prop_match.group(1))
        # Async methods
        func_match = re.match(r"func\s+(\w+)\s*\(", stripped)
        if func_match and "async" in stripped:
            vm_async_methods.add(func_match.group(1))

    for fname in os.listdir(module_dir):
        if not fname.endswith(".swift") or "ViewModel" in fname or "Models" in fname:
            continue
        if "DataProvider" in fname or "Registration" in fname:
            continue

        fpath = os.path.join(module_dir, fname)
        with open(fpath) as f:
            original = f.read()
        code = original

        # Fix 1: Async calls without Task { await } wrapper in Button actions
        # Pattern: viewModel.deleteEntry(...) or viewModel.addEntry(...) without Task { await }
        for method in vm_async_methods:
            # Fix: viewModel.method(xxx) alone (not already in Task { await })
            # Match Button { viewModel.asyncMethod(args) } — needs Task { await } wrapper
            pattern = rf'(Button\s*\{{[^{{}}]*?)(?<!await\s)viewModel\.{method}\(([^)]*)\)([^{{}}]*?\}})'
            replacement = rf'\1Task {{ await viewModel.{method}(\2) }}\3'
            code, n = re.subn(pattern, replacement, code, flags=re.DOTALL)
            fix_count += n

            # Also fix standalone calls in closures: { viewModel.method(args) }
            # But not if already wrapped in Task { await }
            pattern2 = rf'(?<!\bawait\s)(?<!\bTask\s\{{\s)viewModel\.{method}\(([^)]*)\)'
            # Only apply in non-ViewModel files (Views)
            matches = list(re.finditer(pattern2, code))
            for m in reversed(matches):
                # Check if already inside Task { await }
                preceding = code[max(0, m.start()-50):m.start()]
                if "Task {" in preceding and "await" in preceding:
                    continue
                # Check if already preceded by await
                if preceding.rstrip().endswith("await"):
                    continue
                old = m.group(0)
                new = f"Task {{ await viewModel.{method}({m.group(1)}) }}"
                code = code[:m.start()] + new + code[m.end():]
                fix_count += 1

        # Fix 2: .hubAccentYellow / .hubAccentGreen / .hubAccentRed without Color. prefix
        # in .foregroundStyle() context
        for color in ["hubAccentYellow", "hubAccentGreen", "hubAccentRed", "hubPrimary", "hubPrimaryLight"]:
            # Match .foregroundStyle(.hubXxx) — needs Color. prefix
            pattern = rf'\.foregroundStyle\(\s*\.{color}'
            replacement = f'.foregroundStyle(Color.{color}'
            code, n = re.subn(pattern, replacement, code)
            fix_count += n
            # Also in .fill() and .stroke() contexts
            for ctx in [".fill(", ".stroke(", ".tint("]:
                pattern = rf'{re.escape(ctx)}\s*\.{color}'
                replacement = f'{ctx}Color.{color}'
                code, n = re.subn(pattern, replacement, code)
                fix_count += n

        # Fix 3: HubTextField("label", text:) → HubTextField(placeholder: "label", text:)
        pattern = r'HubTextField\("([^"]*)",\s*text:'
        replacement = r'HubTextField(placeholder: "\1", text:'
        code, n = re.subn(pattern, replacement, code)
        fix_count += n

        # Fix 4: SectionHeader("label") → SectionHeader(title: "label")
        pattern = r'SectionHeader\("([^"]*?)"\)'
        replacement = r'SectionHeader(title: "\1")'
        code, n = re.subn(pattern, replacement, code)
        fix_count += n

        # Fix 5: Remove `import Charts` — ModuleChartView handles it
        code, n = re.subn(r'\nimport Charts\n', '\n', code)
        fix_count += n

        if code != original:
            with open(fpath, "w") as f:
                f.write(code)
            print(f"    [AUTOFIX] {fname}: applied deterministic fixes")

    return fix_count


# ─────────────────────────────────────────────────────────────────────
# Phase 3: Build + Auto-Fix
# ─────────────────────────────────────────────────────────────────────

def build_project() -> tuple[bool, str]:
    """Run xcodegen + xcodebuild."""
    print("  [BUILD] xcodegen generate...")
    result = subprocess.run(
        ["xcodegen", "generate"], cwd=RYANHUB_ROOT,
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        return False, f"xcodegen failed:\n{result.stderr}"

    print("  [BUILD] xcodebuild...")
    result = subprocess.run(
        ["xcodebuild", "-scheme", "RyanHub",
         "-destination", "platform=iOS Simulator,name=iPhone 17 Pro",
         "build"],
        cwd=RYANHUB_ROOT, capture_output=True, text=True, timeout=300,
    )
    if result.returncode != 0:
        errors = "\n".join(line for line in result.stdout.split("\n") if "error:" in line)
        return False, errors or result.stderr[:2000]
    return True, ""


def fix_compilation_errors(spec: dict, module_dir: str, errors: str) -> bool:
    """Use Claude to fix compilation errors."""
    files_content = {}
    for fname in sorted(os.listdir(module_dir)):
        if fname.endswith(".swift"):
            with open(os.path.join(module_dir, fname)) as f:
                files_content[fname] = f.read()

    files_str = "\n\n".join(f"--- {fn} ---\n{c}" for fn, c in files_content.items())

    prompt = f"""Fix these Swift compilation errors in a RyanHub dynamic module.

ERRORS:
{errors[:3000]}

CURRENT FILES:
{files_str}

{DESIGN_SYSTEM_DOC}

{SHARED_COMPONENTS_DOC}

CRITICAL API RULES:
- SectionHeader(title: "Label") — requires `title:` label
- HubTextField(placeholder: "Label", text: $binding) — requires `placeholder:` label
- HubButton("Label") {{ action }} — positional title
- HubCard {{ content }} — trailing closure, no params
- ChartDataPoint(label: String, value: Double) — two params
- ModuleInsight(type: InsightType, title: String, message: String) — three params
- StatTrend.from(change: Double, format: String, invertPositive: Bool) — static method

CRITICAL — PROPERTY NAME MISMATCHES:
- The ViewModel file above defines ALL available properties. Views must ONLY use those exact names.
- If a view references `weeklyChartData` but ViewModel has `chartData`, change to `chartData`
- If a view references `currentStreak` but ViewModel has `careStreak`, change to `careStreak`
- If a view references `todayEntries` but it's private in ViewModel, find a public alternative
- Check ViewModel.addEntry() signature — it may take individual params, not an Entry struct
- If insights is [String] not [ModuleInsight], replace InsightsList() with ForEach+Text

Return COMPLETE fixed file contents:
--- FileName.swift ---
<complete content>
--- AnotherFile.swift ---
<complete content>

Only include files that need changes. No markdown fences. No explanation.
"""
    response = call_claude(prompt, max_tokens=16000, timeout=300, disable_tools=True)

    file_pattern = r"---\s*(\w+\.swift)\s*---\n([\s\S]*?)(?=---\s*\w+\.swift\s*---|$)"
    matches = re.findall(file_pattern, response)
    if not matches:
        print("  [FIX] Could not parse fix response")
        return False

    for fname, content in matches:
        content = content.strip()
        if content:
            with open(os.path.join(module_dir, fname), "w") as f:
                f.write(content)
            print(f"  [FIX] Updated {fname}")
    return True


# ─────────────────────────────────────────────────────────────────────
# Phase 4: Quality Gate
# ─────────────────────────────────────────────────────────────────────

def cross_validate_views_vs_vm(module_dir: str, spec: dict) -> tuple[int, list[str]]:
    """Cross-validate that all viewModel.xxx references in Views actually exist in ViewModel.
    Returns (fix_count, remaining_issues). Attempts auto-fix where possible."""
    name = spec["moduleName"]
    vm_file = os.path.join(module_dir, f"{name}ViewModel.swift")
    if not os.path.exists(vm_file):
        return 0, ["ViewModel file not found"]

    with open(vm_file) as f:
        vm_code = f.read()

    # Extract all public property/method names from ViewModel
    vm_public_names = set()
    vm_all_names = set()  # Including private, for fuzzy matching
    for line in vm_code.split("\n"):
        stripped = line.strip()
        # Properties
        prop_match = re.match(r"(?:private\s+)?var\s+(\w+)\s*:", stripped)
        if prop_match:
            pname = prop_match.group(1)
            vm_all_names.add(pname)
            if "private " not in stripped:
                vm_public_names.add(pname)
        # Methods
        func_match = re.match(r"(?:private\s+)?func\s+(\w+)\s*\(", stripped)
        if func_match:
            fname_m = func_match.group(1)
            vm_all_names.add(fname_m)
            if "private " not in stripped:
                vm_public_names.add(fname_m)

    # Always-available base properties
    vm_public_names.update(["entries", "isLoading", "errorMessage"])

    fix_count = 0
    issues = []

    # Scan all view files for viewModel.xxx references
    for fname in os.listdir(module_dir):
        if not fname.endswith(".swift"):
            continue
        if "ViewModel" in fname or "Models" in fname or "DataProvider" in fname or "Registration" in fname:
            continue

        fpath = os.path.join(module_dir, fname)
        with open(fpath) as f:
            view_code = f.read()

        # Find all viewModel.xxx references
        refs = re.findall(r'viewModel\.(\w+)', view_code)
        unique_refs = set(refs)

        missing = unique_refs - vm_public_names
        if not missing:
            continue

        # Try to auto-fix by finding close matches in VM
        original_code = view_code
        for ref in missing:
            # Check if it's a private property — make it public in VM
            if ref in vm_all_names and ref not in vm_public_names:
                # It exists but is private — make it non-private in ViewModel
                vm_code_new = re.sub(
                    rf'(\s+)private\s+(var\s+{ref}\s*:)',
                    r'\1\2',
                    vm_code
                )
                if vm_code_new != vm_code:
                    vm_code = vm_code_new
                    vm_public_names.add(ref)
                    fix_count += 1
                    print(f"    [XVAL] Made {ref} public in ViewModel (referenced by {fname})")
                    continue

            # Otherwise it's a truly missing property — log as issue
            issues.append(f"{fname} references viewModel.{ref} which doesn't exist in ViewModel")

        # Write back VM if modified
        with open(vm_file, "w") as f:
            f.write(vm_code)

    return fix_count, issues


def phase4_quality_gate(module_dir: str, spec: dict) -> list[str]:
    """Check quality criteria. Returns list of issues (empty = pass)."""
    issues = []
    name = spec["moduleName"]

    # Count view files
    swift_files = [f for f in os.listdir(module_dir) if f.endswith(".swift")]
    view_files = [f for f in swift_files
                  if "View" in f and f != f"{name}View.swift"
                  and "Registration" not in f and "DataProvider" not in f
                  and "ViewModel" not in f and "Models" not in f]

    if len(view_files) < 2:
        issues.append(f"Only {len(view_files)} sub-view files (need at least 2)")

    # Check ViewModel richness
    vm_file = os.path.join(module_dir, f"{name}ViewModel.swift")
    vm_code = ""
    if os.path.exists(vm_file):
        with open(vm_file) as f:
            vm_code = f.read()
        # Count computed properties (var ... { ... })
        computed_count = len(re.findall(r"var \w+.*\{", vm_code))
        # Subtract stored properties (var ... = ...)
        stored_count = len(re.findall(r"var \w+.*=", vm_code))
        net_computed = computed_count - stored_count
        if net_computed < 4:
            issues.append(f"ViewModel has only ~{net_computed} computed properties (need 4+)")

    # Check for TextField misuse on non-text fields
    for fname in swift_files:
        if "View" not in fname:
            continue
        fpath = os.path.join(module_dir, fname)
        with open(fpath) as f:
            code = f.read()
        tf_count = code.count("TextField(")
        if tf_count > 3:
            issues.append(f"{fname}: {tf_count} TextFields (prefer Stepper/Slider/Picker)")

    # NEW: Check async wrapper compliance
    vm_async_methods = set()
    for line in vm_code.split("\n"):
        stripped = line.strip()
        if "private " in stripped:
            continue
        func_match = re.match(r"func\s+(\w+)\s*\(", stripped)
        if func_match and "async" in stripped:
            vm_async_methods.add(func_match.group(1))

    for fname in swift_files:
        if "ViewModel" in fname or "Models" in fname or "DataProvider" in fname or "Registration" in fname:
            continue
        fpath = os.path.join(module_dir, fname)
        with open(fpath) as f:
            code = f.read()

        for method in vm_async_methods:
            # Find calls to async methods not inside Task { await }
            pattern = rf'(?<!\bawait\s)viewModel\.{method}\('
            bare_calls = re.findall(pattern, code)
            if bare_calls:
                # Check if each is already inside a Task block
                for m in re.finditer(pattern, code):
                    preceding = code[max(0, m.start()-80):m.start()]
                    if "Task {" not in preceding and "Task{" not in preceding:
                        issues.append(f"{fname}: viewModel.{method}() called without Task {{ await }} wrapper")
                        break

    # NEW: Check View↔ViewModel property references
    vm_public_names = set(["entries", "isLoading", "errorMessage"])
    for line in vm_code.split("\n"):
        stripped = line.strip()
        if "private " in stripped or "fileprivate " in stripped:
            continue
        prop_match = re.match(r"var\s+(\w+)\s*:", stripped)
        if prop_match:
            vm_public_names.add(prop_match.group(1))
        func_match = re.match(r"func\s+(\w+)\s*\(", stripped)
        if func_match:
            vm_public_names.add(func_match.group(1))

    for fname in swift_files:
        if "ViewModel" in fname or "Models" in fname or "DataProvider" in fname or "Registration" in fname:
            continue
        fpath = os.path.join(module_dir, fname)
        with open(fpath) as f:
            code = f.read()
        refs = set(re.findall(r'viewModel\.(\w+)', code))
        missing = refs - vm_public_names
        for ref in missing:
            issues.append(f"{fname}: references viewModel.{ref} which doesn't exist")

    # NEW: Check argument label patterns
    for fname in swift_files:
        if "ViewModel" in fname or "Models" in fname or "DataProvider" in fname or "Registration" in fname:
            continue
        fpath = os.path.join(module_dir, fname)
        with open(fpath) as f:
            code = f.read()
        # HubTextField without placeholder: label
        if re.search(r'HubTextField\("[^"]*",\s*text:', code):
            issues.append(f"{fname}: HubTextField missing placeholder: argument label")
        # SectionHeader without title: label
        if re.search(r'SectionHeader\("[^"]*"\)', code):
            issues.append(f"{fname}: SectionHeader missing title: argument label")

    return issues


# ─────────────────────────────────────────────────────────────────────
# Main Pipeline
# ─────────────────────────────────────────────────────────────────────

def update_bootstrap():
    """Regenerate DynamicModuleBootstrap.swift."""
    registrations = []
    for dirname in sorted(os.listdir(DYNAMIC_MODULES_DIR)):
        dirpath = os.path.join(DYNAMIC_MODULES_DIR, dirname)
        if not os.path.isdir(dirpath):
            continue
        reg_file = os.path.join(dirpath, f"{dirname}Registration.swift")
        if os.path.exists(reg_file):
            registrations.append(dirname)

    calls = "\n".join(f"        register{n}()" for n in registrations)
    if not calls:
        calls = "        // No dynamic modules generated yet."

    content = f'''import Foundation

// MARK: - Dynamic Module Bootstrap

/// Auto-generated. Registers all dynamic modules at app startup.
extension DynamicModuleRegistry {{
    static func bootstrapAll() {{
{calls}
    }}
}}
'''
    with open(BOOTSTRAP_FILE, "w") as f:
        f.write(content)
    print(f"[OK] Bootstrap: {len(registrations)} module(s)")


def generate_module(description: str, skip_build: bool = False) -> bool:
    """Full v2 pipeline: Deep Plan → Generate → Build → Quality Gate."""
    print(f"\n{'='*60}")
    print(f"Module: {description}")
    print(f"{'='*60}\n")

    # Phase 1: Deep Planning
    try:
        spec = phase1_deep_planning(description)
    except Exception as e:
        print(f"[ERROR] Phase 1 failed: {e}")
        return False

    name = spec["moduleName"]
    module_dir = os.path.join(DYNAMIC_MODULES_DIR, name)
    os.makedirs(module_dir, exist_ok=True)

    # Phase 2: Code Generation
    try:
        files = phase2_generate_code(spec)
    except Exception as e:
        print(f"[ERROR] Phase 2 failed: {e}")
        return False

    for fname, content in files.items():
        with open(os.path.join(module_dir, fname), "w") as f:
            f.write(content)
        print(f"  Wrote {fname}")

    # Save spec
    with open(os.path.join(module_dir, "spec.json"), "w") as f:
        json.dump(spec, f, indent=2)

    # Update bootstrap
    update_bootstrap()

    # Phase 2.5: Deterministic fixes + cross-validation
    vm_code = files.get(f"{name}ViewModel.swift", "")
    print("\n[Phase 2.5] Deterministic auto-fixes...")
    det_fixes = deterministic_fixes(module_dir, vm_code)
    print(f"  Applied {det_fixes} deterministic fixes")

    print("[Phase 2.5] Cross-validating Views vs ViewModel...")
    xval_fixes, xval_issues = cross_validate_views_vs_vm(module_dir, spec)
    if xval_fixes:
        print(f"  Auto-fixed {xval_fixes} cross-validation issues")
    if xval_issues:
        print(f"  Remaining cross-validation issues ({len(xval_issues)}):")
        for issue in xval_issues:
            print(f"    - {issue}")

    # Phase 4: Quality Gate (pre-build)
    print("\n[Phase 4] Quality gate...")
    issues = phase4_quality_gate(module_dir, spec)
    if issues:
        print(f"  Warnings ({len(issues)}):")
        for issue in issues:
            print(f"    - {issue}")
    else:
        print("  All checks passed!")

    if skip_build:
        print("[SKIP] Build skipped")
        return True

    # Phase 3: Build + Fix
    print("\n[Phase 3] Build...")
    for attempt in range(3):
        success, errors = build_project()
        if success:
            print(f"  BUILD SUCCEEDED (attempt {attempt + 1})")
            return True

        print(f"  BUILD FAILED (attempt {attempt + 1}/3)")
        print(f"  Errors: {errors[:500]}")

        if attempt < 2:
            print("  Attempting auto-fix...")
            fixed = fix_compilation_errors(spec, module_dir, errors)
            if not fixed:
                print("  Auto-fix parsing failed, retrying...")

    print("[ERROR] All build attempts failed")
    return False


def _parse_errors_by_module(errors: str) -> dict[str, str]:
    """Group build errors by module directory name."""
    module_errors: dict[str, list[str]] = {}
    for line in errors.split("\n"):
        if "error:" in line.lower():
            match = re.search(r"DynamicModules/(\w+)/", line)
            if match:
                mod = match.group(1)
                module_errors.setdefault(mod, []).append(line.strip())
    return {k: "\n".join(v) for k, v in module_errors.items()}


def batch_generate(scenarios_file: str, skip_build: bool = False):
    """Generate multiple modules, single build at end."""
    with open(scenarios_file) as f:
        scenarios = json.load(f)

    results = []
    for i, scenario in enumerate(scenarios, 1):
        desc = scenario if isinstance(scenario, str) else scenario.get("description", "")
        print(f"\n[{i}/{len(scenarios)}] {desc}")
        success = generate_module(desc, skip_build=True)
        results.append({"description": desc, "success": success})

    if not skip_build:
        print(f"\n{'='*60}")
        print("Final build with all modules...")
        print(f"{'='*60}")
        for attempt in range(5):
            success, errors = build_project()
            if success:
                print(f"BUILD SUCCEEDED (attempt {attempt + 1})")
                break
            print(f"BUILD FAILED (attempt {attempt + 1}/5)")
            # Parse errors by module and fix each one
            module_errors = _parse_errors_by_module(errors)
            if module_errors:
                for mod_name, mod_errs in module_errors.items():
                    mod_dir = os.path.join(DYNAMIC_MODULES_DIR, mod_name)
                    spec_path = os.path.join(mod_dir, "spec.json")
                    if os.path.exists(spec_path):
                        with open(spec_path) as f:
                            mod_spec = json.load(f)
                        # First try deterministic fixes
                        vm_path = os.path.join(mod_dir, f"{mod_name}ViewModel.swift")
                        vm_c = ""
                        if os.path.exists(vm_path):
                            with open(vm_path) as vf:
                                vm_c = vf.read()
                        det_n = deterministic_fixes(mod_dir, vm_c)
                        cross_validate_views_vs_vm(mod_dir, mod_spec)
                        if det_n > 0:
                            print(f"  [AUTOFIX] {mod_name}: {det_n} deterministic fixes")
                        # Then Claude-based fix for remaining errors
                        print(f"  Auto-fixing {mod_name} ({mod_errs.count(chr(10))+1} errors)...")
                        fix_compilation_errors(mod_spec, mod_dir, mod_errs)
                    else:
                        print(f"  [SKIP] No spec.json for {mod_name}")
            else:
                print(f"  Could not parse errors by module:\n{errors[:500]}")
        else:
            print("[ERROR] Final build failed after 5 attempts")

    # Summary
    print(f"\n{'='*60}")
    print("BATCH SUMMARY")
    print(f"{'='*60}")
    for r in results:
        status = "OK" if r["success"] else "FAIL"
        print(f"  [{status}] {r['description']}")
    succeeded = sum(1 for r in results if r["success"])
    print(f"\n{succeeded}/{len(results)} modules generated")


def list_modules():
    """List all generated dynamic modules."""
    print(f"\nDynamic Modules:\n")
    count = 0
    for dirname in sorted(os.listdir(DYNAMIC_MODULES_DIR)):
        dirpath = os.path.join(DYNAMIC_MODULES_DIR, dirname)
        if not os.path.isdir(dirpath):
            continue
        spec_path = os.path.join(dirpath, "spec.json")
        if os.path.exists(spec_path):
            with open(spec_path) as f:
                spec = json.load(f)
            swift_files = [f for f in os.listdir(dirpath) if f.endswith(".swift")]
            view_files = [f for f in swift_files if "View" in f and "ViewModel" not in f]
            print(f"  {spec['moduleName']}: {spec['displayName']} ({spec['icon']})")
            print(f"    {spec.get('subtitle', '')}")
            print(f"    Files: {len(swift_files)} swift, {len(view_files)} views")
            count += 1
    if count == 0:
        print("  (no modules)")
    print(f"\nTotal: {count}")


def delete_all_modules():
    """Delete all generated module directories."""
    count = 0
    for dirname in os.listdir(DYNAMIC_MODULES_DIR):
        dirpath = os.path.join(DYNAMIC_MODULES_DIR, dirname)
        if os.path.isdir(dirpath):
            shutil.rmtree(dirpath)
            print(f"  Deleted {dirname}")
            count += 1
    update_bootstrap()
    print(f"Deleted {count} modules")


def main():
    parser = argparse.ArgumentParser(description="RyanHub Dynamic Module Generator v2")
    parser.add_argument("--description", "-d", help="Natural language module description")
    parser.add_argument("--batch", "-b", help="JSON file with batch scenarios")
    parser.add_argument("--list", "-l", action="store_true", help="List modules")
    parser.add_argument("--skip-build", action="store_true", help="Skip xcodebuild")
    parser.add_argument("--update-bootstrap", action="store_true", help="Regenerate bootstrap")
    parser.add_argument("--delete-all", action="store_true", help="Delete all generated modules")
    args = parser.parse_args()

    if args.list:
        list_modules()
    elif args.update_bootstrap:
        update_bootstrap()
    elif args.delete_all:
        delete_all_modules()
    elif args.batch:
        batch_generate(args.batch, skip_build=args.skip_build)
    elif args.description:
        success = generate_module(args.description, skip_build=args.skip_build)
        sys.exit(0 if success else 1)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
