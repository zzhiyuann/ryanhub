#!/usr/bin/env python3
"""
Dynamic Module Generator for RyanHub

Takes a natural language description and generates a complete toolkit module:
  1. Generates a module spec (JSON) via Claude
  2. Generates Swift source files following exact RyanHub patterns
  3. Updates the bootstrap file
  4. Runs xcodegen + xcodebuild with auto-fix loop (max 3 retries)

Usage:
  python3 scripts/generate-module.py --description "Track daily water intake"
  python3 scripts/generate-module.py --batch scenarios.json
  python3 scripts/generate-module.py --list  # list all generated modules
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

# Available icon colors matching DynamicModuleDescriptor.iconColor
ICON_COLORS = [
    "hubPrimary",
    "hubPrimaryLight",
    "hubAccentGreen",
    "hubAccentRed",
    "hubAccentYellow",
]


def call_claude(prompt: str, max_tokens: int = 4096) -> str:
    """Call Claude CLI with a prompt and return the response."""
    # Must unset CLAUDE_CODE/CLAUDECODE to avoid nesting error
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDE_CODE", "CLAUDECODE")}
    env["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] = str(max_tokens)
    result = subprocess.run(
        [CLAUDE_PATH, "--print", "--model", "sonnet", "-p", prompt],
        capture_output=True,
        text=True,
        timeout=180,
        env=env,
    )
    if result.returncode != 0:
        print(f"[ERROR] Claude call failed: {result.stderr[:500]}")
        return ""
    return result.stdout.strip()


def generate_spec(description: str) -> dict:
    """Generate a module specification from a natural language description."""
    prompt = f"""You are generating a module spec for a personal iOS toolkit app.
Given this user need: "{description}"

Generate a JSON object with these exact fields:
- moduleId: camelCase identifier (e.g. "waterIntake"), no spaces, lowercase start
- moduleName: PascalCase name (e.g. "WaterIntake"), used in Swift type names
- displayName: human-readable (e.g. "Water Intake")
- shortName: 1-2 words for menu bar (e.g. "Water")
- subtitle: brief description for card (e.g. "Track daily hydration")
- icon: an SF Symbol name (e.g. "drop.fill"). Must be a real SF Symbol.
- iconColor: one of {ICON_COLORS}
- relevanceKeywords: array of 5-10 lowercase keywords for AI context matching (include both English and Chinese if applicable)
- dataFields: array of objects with:
  - name: Swift property name (camelCase)
  - type: Swift type ("String", "Double", "Int", "Bool", "String?", "Double?")
  - label: human-readable label for the UI

IMPORTANT: Return ONLY valid JSON, no markdown fences, no explanation.
The dataFields should capture the core data model for tracking this need.
Include a "note" field (String?) for optional user notes.
"""
    response = call_claude(prompt)
    # Extract JSON from response (handle potential markdown fences)
    json_match = re.search(r"\{[\s\S]*\}", response)
    if not json_match:
        raise ValueError(f"No JSON found in Claude response:\n{response[:500]}")
    return json.loads(json_match.group())


def generate_data_provider(spec: dict) -> str:
    """Generate the DataProvider Swift file."""
    name = spec["moduleName"]
    module_id = spec["moduleId"]
    display_name = spec["displayName"]
    keywords = spec["relevanceKeywords"]
    fields = spec["dataFields"]

    # Filter out built-in fields
    fields = [f for f in fields if f["name"] not in ("id", "date")]

    # Build context summary showing recent entries
    field_descriptions = ", ".join(f['label'] for f in fields if f['name'] != 'note')

    keywords_str = ", ".join(f'"{k}"' for k in keywords)

    return f'''import Foundation

// MARK: - {name} Data Provider

/// Provides {display_name.lower()} data for chat context injection.
/// Reads from bridge server at /modules/{module_id}/data.
enum {name}DataProvider: ToolkitDataProvider {{

    static let toolkitId = "{module_id}"
    static let displayName = "{display_name}"

    static let relevanceKeywords: [String] = [
        {keywords_str}
    ]

    private static var bridgeBaseURL: String {{
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap {{ URL(string: $0)?.host }}
            .map {{ "http://\\($0):18790" }}
            ?? "http://localhost:18790"
    }}

    static func buildContextSummary() -> String? {{
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_{module_id}_cache"),
              let entries = try? JSONDecoder().decode([{name}Entry].self, from: data),
              !entries.isEmpty else {{
            return nil
        }}

        var lines: [String] = ["[\\(displayName)]"]
        lines.append("Total entries: \\(entries.count)")

        // Show last 5 entries
        let recent = entries.suffix(5)
        for entry in recent {{
            lines.append("  - \\(entry.summaryLine)")
        }}

        // Action hints for the AI agent
        lines.append("Actions:")
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/{module_id}/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/{module_id}/data")
        lines.append("[End \\(displayName)]")
        return lines.joined(separator: "\\n")
    }}
}}
'''


def generate_models(spec: dict) -> str:
    """Generate the Models Swift file."""
    name = spec["moduleName"]
    fields = spec["dataFields"]

    # Filter out fields that are already provided by the template (id, date)
    fields = [f for f in fields if f["name"] not in ("id", "date")]

    # Build struct fields
    field_lines = []
    for f in fields:
        field_lines.append(f"    var {f['name']}: {f['type']}")

    fields_str = "\n".join(field_lines)

    # Build summary line (use first non-note, non-optional field)
    summary_parts = []
    for f in fields:
        if f["name"] == "note":
            continue
        if f["type"].endswith("?"):
            summary_parts.append(
                f'if let v = {f["name"]} {{ parts.append("\\(v)") }}'
            )
        elif f["type"] == "String":
            summary_parts.append(f'parts.append({f["name"]})')
        else:
            summary_parts.append(f'parts.append("\\({f["name"]})")')

    summary_code = "\n            ".join(summary_parts) if summary_parts else 'parts.append("entry")'

    return f'''import Foundation

// MARK: - {name} Models

struct {name}Entry: Codable, Identifiable {{
    var id: String = UUID().uuidString
    var date: String = {{
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }}()
{fields_str}

    /// One-line summary for context injection.
    var summaryLine: String {{
        var parts: [String] = [date]
        {summary_code}
        return parts.joined(separator: " | ")
    }}
}}
'''


def generate_view_model(spec: dict) -> str:
    """Generate the ViewModel Swift file."""
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

    init() {{
        Task {{ await loadData() }}
    }}

    func loadData() async {{
        isLoading = true
        defer {{ isLoading = false }}

        do {{
            let url = URL(string: "\\(bridgeBaseURL)/modules/{module_id}/data")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            entries = try decoder.decode([{name}Entry].self, from: data)
            // Cache for DataProvider context injection
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
            let _ = try await URLSession.shared.data(for: request)
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
            let _ = try await URLSession.shared.data(for: request)
            await loadData()
        }} catch {{
            errorMessage = "Failed to delete entry"
        }}
    }}
}}
'''


def generate_view(spec: dict) -> str:
    """Generate the View Swift file using Claude for creative UI layout."""
    name = spec["moduleName"]
    display_name = spec["displayName"]
    fields = spec["dataFields"]
    icon = spec["icon"]

    # Build field descriptions for Claude
    field_desc = "\n".join(
        f"  - {f['name']}: {f['type']} ({f['label']})" for f in fields
    )

    prompt = f"""Generate a SwiftUI View for a personal tracker module called "{display_name}".

Module name (for types): {name}
SF Symbol icon: {icon}
Data model fields:
{field_desc}

The view must follow these EXACT patterns:
1. Import SwiftUI only
2. Use `@Environment(\\.colorScheme) private var colorScheme`
3. Use `@State private var viewModel = {name}ViewModel()`
4. Main body: ScrollView with VStack(spacing: HubLayout.sectionSpacing)
5. Background: `.background(AdaptiveColors.background(for: colorScheme))`
6. Load data: `.task {{ await viewModel.loadData() }}`
7. Use these design system components:
   - Colors: `Color.hubPrimary`, `AdaptiveColors.textPrimary(for: colorScheme)`, `AdaptiveColors.textSecondary(for: colorScheme)`, `AdaptiveColors.surface(for: colorScheme)`, `AdaptiveColors.border(for: colorScheme)`
   - Layout: `HubLayout.standardPadding`, `HubLayout.sectionSpacing`, `HubLayout.itemSpacing`, `HubLayout.cardCornerRadius`
   - Typography: `.hubTitle`, `.hubHeading`, `.hubBody`, `.hubCaption`
8. Include:
   - A header section with icon and title
   - A summary card showing total entries count (use `HubCard {{ ... }}`)
   - A list of recent entries (each in `HubCard {{ ... }}`)
   - An "Add Entry" section with inputs and a submit button
   - Swipe-to-delete on entries
9. Use `@State` for input fields in the add form
10. Entry model is `{name}Entry` with fields: id (String), date (String), {', '.join(f['name'] + ' (' + f['type'] + ')' for f in fields)}
11. For optional fields (type ending with ?), use if-let to display

CRITICAL API RULES — violations will cause compilation errors:
- `SectionHeader(title: "Label")` — MUST use `title:` parameter label
- `HubTextField(placeholder: "Label", text: $binding)` — MUST use `placeholder:` parameter label
- `HubButton("Label") {{ action }}` — title is positional (no label)
- `HubCard {{ content }}` — trailing closure ViewBuilder, no parameters
- ViewModel has ONLY these methods: `loadData()`, `addEntry(_ entry: {name}Entry)`, `deleteEntry(_ entry: {name}Entry)`
- To add: create a `{name}Entry(field1: val1, field2: val2, ...)` then call `await viewModel.addEntry(entry)`
- To delete: call `await viewModel.deleteEntry(entry)` — pass the WHOLE entry, NOT just the id
- Do NOT invent methods like `addEntry(field1:field2:...)` or `deleteEntry(id:)` — they don't exist

Return ONLY the Swift code. No markdown fences. No explanation. Start with `import SwiftUI`.
"""
    try:
        code = call_claude(prompt, max_tokens=8192)
    except Exception as e:
        print(f"  [WARN] Claude view generation failed ({e}), using template fallback")
        return generate_minimal_view(spec)

    # Strip markdown fences if present
    code = re.sub(r"^```swift\s*\n?", "", code)
    code = re.sub(r"\n?```\s*$", "", code)

    # Validate it starts with import
    if not code.strip().startswith("import"):
        # Fallback: generate a minimal view
        return generate_minimal_view(spec)

    return code


def generate_minimal_view(spec: dict) -> str:
    """Generate a minimal but functional view as fallback."""
    name = spec["moduleName"]
    display_name = spec["displayName"]
    icon = spec["icon"]
    fields = [f for f in spec["dataFields"] if f["name"] not in ("id", "date")]

    # Build input fields
    input_states = []
    input_fields_ui = []
    entry_init_args = []

    for f in fields:
        fname = f["name"]
        ftype = f["type"]
        label = f["label"]
        is_optional = ftype.endswith("?")
        base_type = ftype.rstrip("?")

        input_states.append(f'    @State private var input{fname.capitalize()}: String = ""')

        input_fields_ui.append(f'''                    TextField("{label}", text: $input{fname.capitalize()})
                        .textFieldStyle(.roundedBorder)''')

        if base_type == "Double":
            val = f"Double(input{fname.capitalize()})" if is_optional else f"Double(input{fname.capitalize()}) ?? 0"
        elif base_type == "Int":
            val = f"Int(input{fname.capitalize()})" if is_optional else f"Int(input{fname.capitalize()}) ?? 0"
        elif base_type == "Bool":
            val = f"input{fname.capitalize()} == \"true\""
        elif is_optional:
            val = f"input{fname.capitalize()}.isEmpty ? nil : input{fname.capitalize()}"
        else:
            val = f"input{fname.capitalize()}"

        entry_init_args.append(f"{fname}: {val}")

    input_states_str = "\n".join(input_states)
    input_fields_str = "\n".join(input_fields_ui)
    entry_args_str = ", ".join(entry_init_args)

    # Build entry display
    display_fields = []
    for f in fields:
        fname = f["name"]
        label = f["label"]
        if f["type"].endswith("?"):
            display_fields.append(
                f'                                if let val = entry.{fname} {{ Text("{label}: \\(val)").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme)) }}'
            )
        else:
            display_fields.append(
                f'                                Text("{label}: \\(entry.{fname})").font(.hubCaption).foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))'
            )
    display_fields_str = "\n".join(display_fields)

    # Reset fields
    reset_lines = []
    for f in fields:
        reset_lines.append(f'                            input{f["name"].capitalize()} = ""')
    reset_str = "\n".join(reset_lines)

    return f'''import SwiftUI

struct {name}View: View {{
    @Environment(\\.colorScheme) private var colorScheme
    @State private var viewModel = {name}ViewModel()
{input_states_str}

    var body: some View {{
        ScrollView {{
            VStack(spacing: HubLayout.sectionSpacing) {{
                // Header
                HStack(spacing: 12) {{
                    ZStack {{
                        Circle()
                            .fill(Color.hubPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "{icon}")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                    }}
                    VStack(alignment: .leading, spacing: 2) {{
                        Text("{display_name}")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("\\(viewModel.entries.count) entries")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }}
                    Spacer()
                }}

                // Add entry form
                VStack(spacing: HubLayout.itemSpacing) {{
                    SectionHeader(title: "Add Entry")
{input_fields_str}
                    Button {{
                        Task {{
                            let entry = {name}Entry({entry_args_str})
                            await viewModel.addEntry(entry)
{reset_str}
                        }}
                    }} label: {{
                        Text("Add")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: HubLayout.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                                    .fill(Color.hubPrimary)
                            )
                    }}
                }}
                .padding(HubLayout.standardPadding)
                .background(
                    RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                        .fill(AdaptiveColors.surface(for: colorScheme))
                )

                // Entries list
                if !viewModel.entries.isEmpty {{
                    VStack(spacing: HubLayout.itemSpacing) {{
                        SectionHeader(title: "Recent Entries")
                        ForEach(viewModel.entries.reversed()) {{ entry in
                            HStack {{
                                VStack(alignment: .leading, spacing: 4) {{
                                    Text(entry.date)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
{display_fields_str}
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
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AdaptiveColors.surface(for: colorScheme))
                            )
                        }}
                    }}
                }}
            }}
            .padding(HubLayout.standardPadding)
        }}
        .background(AdaptiveColors.background(for: colorScheme))
        .task {{ await viewModel.loadData() }}
    }}
}}
'''


def generate_registration(spec: dict) -> str:
    """Generate the Registration Swift file."""
    name = spec["moduleName"]
    module_id = spec["moduleId"]
    display_name = spec["displayName"]
    short_name = spec["shortName"]
    subtitle = spec["subtitle"]
    icon = spec["icon"]
    icon_color = spec["iconColor"]

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


def update_bootstrap():
    """Regenerate DynamicModuleBootstrap.swift with all registered modules."""
    # Scan for Registration files
    registrations = []
    for dirname in sorted(os.listdir(DYNAMIC_MODULES_DIR)):
        dirpath = os.path.join(DYNAMIC_MODULES_DIR, dirname)
        if not os.path.isdir(dirpath):
            continue
        reg_file = os.path.join(dirpath, f"{dirname}Registration.swift")
        if os.path.exists(reg_file):
            registrations.append(dirname)

    # Generate bootstrap
    calls = "\n".join(f"        register{name}()" for name in registrations)
    if not calls:
        calls = "        // No dynamic modules generated yet."

    content = f'''import Foundation

// MARK: - Dynamic Module Bootstrap

/// Auto-generated file. Registers all dynamically generated modules at app startup.
/// Re-generated by scripts/generate-module.py after each module creation.
/// DO NOT EDIT MANUALLY.
extension DynamicModuleRegistry {{
    static func bootstrapAll() {{
{calls}
    }}
}}
'''
    with open(BOOTSTRAP_FILE, "w") as f:
        f.write(content)
    print(f"[OK] Updated bootstrap with {len(registrations)} module(s)")


def build_project() -> tuple[bool, str]:
    """Run xcodegen + xcodebuild. Returns (success, error_output)."""
    # xcodegen
    print("[BUILD] Running xcodegen generate...")
    result = subprocess.run(
        ["xcodegen", "generate"],
        cwd=RYANHUB_ROOT,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        return False, f"xcodegen failed:\n{result.stderr}"

    # xcodebuild
    print("[BUILD] Running xcodebuild...")
    result = subprocess.run(
        [
            "xcodebuild",
            "-scheme", "RyanHub",
            "-destination", "platform=iOS Simulator,name=iPhone 17 Pro",
            "build",
        ],
        cwd=RYANHUB_ROOT,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if result.returncode != 0:
        # Extract error lines
        errors = "\n".join(
            line for line in result.stdout.split("\n")
            if "error:" in line
        )
        return False, errors or result.stderr[:2000]

    return True, ""


def fix_compilation_errors(spec: dict, module_dir: str, errors: str) -> bool:
    """Use Claude to fix compilation errors in generated files."""
    # Read all files in the module directory
    files_content = {}
    for fname in os.listdir(module_dir):
        if fname.endswith(".swift"):
            fpath = os.path.join(module_dir, fname)
            with open(fpath) as f:
                files_content[fname] = f.read()

    files_str = "\n\n".join(
        f"--- {fname} ---\n{content}" for fname, content in files_content.items()
    )

    prompt = f"""Fix these Swift compilation errors in a dynamically generated RyanHub toolkit module.

ERRORS:
{errors}

CURRENT FILES:
{files_str}

RULES:
- The module uses: ToolkitDataProvider protocol, @Observable @MainActor ViewModel, SwiftUI View
- Design system: Color.hubPrimary, AdaptiveColors.textPrimary(for: colorScheme), HubLayout.standardPadding, .hubTitle/.hubBody/.hubCaption fonts
- Bridge server URL: http://localhost:18790/modules/{spec['moduleId']}/data
- Models must be Codable and Identifiable with id: String and date: String
- CRITICAL API signatures:
  - SectionHeader(title: "Label") — requires `title:` label
  - HubTextField(placeholder: "Label", text: $binding) — requires `placeholder:` label
  - HubButton("Label") {{ action }} — positional title
  - HubCard {{ content }} — trailing closure, no params
  - ViewModel.addEntry(_ entry: {spec['moduleName']}Entry) — takes whole entry, NOT individual fields
  - ViewModel.deleteEntry(_ entry: {spec['moduleName']}Entry) — takes whole entry, NOT id

Return the COMPLETE fixed contents of each file that needs changes, in this format:
--- FileName.swift ---
<complete file content>
--- AnotherFile.swift ---
<complete file content>

Only include files that need changes. Return ONLY the file contents, no markdown fences, no explanation.
"""
    response = call_claude(prompt, max_tokens=8192)

    # Parse response into files
    file_pattern = r"---\s*(\w+\.swift)\s*---\n([\s\S]*?)(?=---\s*\w+\.swift\s*---|$)"
    matches = re.findall(file_pattern, response)

    if not matches:
        print("[FIX] Could not parse Claude fix response")
        return False

    for fname, content in matches:
        content = content.strip()
        if content:
            fpath = os.path.join(module_dir, fname)
            with open(fpath, "w") as f:
                f.write(content)
            print(f"[FIX] Updated {fname}")

    return True


def generate_module(description: str, skip_build: bool = False, use_template_views: bool = False) -> bool:
    """Full pipeline: description → spec → code → build → fix."""
    print(f"\n{'='*60}")
    print(f"Generating module: {description}")
    print(f"{'='*60}\n")

    # Step 1: Generate spec
    print("[1/5] Generating module spec...")
    try:
        spec = generate_spec(description)
    except Exception as e:
        print(f"[ERROR] Spec generation failed: {e}")
        return False

    name = spec["moduleName"]
    module_id = spec["moduleId"]
    print(f"  Module: {name} ({module_id})")
    print(f"  Icon: {spec['icon']} ({spec['iconColor']})")
    print(f"  Fields: {len(spec['dataFields'])}")

    # Step 2: Generate code
    module_dir = os.path.join(DYNAMIC_MODULES_DIR, name)
    os.makedirs(module_dir, exist_ok=True)

    print("[2/5] Generating Swift files...")

    files = {
        f"{name}DataProvider.swift": generate_data_provider(spec),
        f"{name}Models.swift": generate_models(spec),
        f"{name}ViewModel.swift": generate_view_model(spec),
        f"{name}View.swift": generate_minimal_view(spec) if use_template_views else generate_view(spec),
        f"{name}Registration.swift": generate_registration(spec),
    }

    for fname, content in files.items():
        fpath = os.path.join(module_dir, fname)
        with open(fpath, "w") as f:
            f.write(content)
        print(f"  Wrote {fname}")

    # Save spec for reference
    with open(os.path.join(module_dir, "spec.json"), "w") as f:
        json.dump(spec, f, indent=2)

    # Step 3: Update bootstrap
    print("[3/5] Updating bootstrap...")
    update_bootstrap()

    if skip_build:
        print("[SKIP] Build skipped (--skip-build)")
        return True

    # Step 4: Build
    print("[4/5] Building project...")
    for attempt in range(3):
        success, errors = build_project()
        if success:
            print(f"[OK] Build succeeded (attempt {attempt + 1})")
            return True

        print(f"[FAIL] Build failed (attempt {attempt + 1}/3)")
        print(f"  Errors: {errors[:500]}")

        if attempt < 2:
            # Step 5: Auto-fix
            print(f"[5/5] Attempting auto-fix...")
            fixed = fix_compilation_errors(spec, module_dir, errors)
            if not fixed:
                print("[ERROR] Auto-fix failed, retrying build anyway...")
        else:
            print("[ERROR] All 3 build attempts failed")
            return False

    return False


def list_modules():
    """List all generated dynamic modules."""
    print(f"\nDynamic Modules in {DYNAMIC_MODULES_DIR}:\n")
    count = 0
    for dirname in sorted(os.listdir(DYNAMIC_MODULES_DIR)):
        dirpath = os.path.join(DYNAMIC_MODULES_DIR, dirname)
        if not os.path.isdir(dirpath):
            continue
        spec_path = os.path.join(dirpath, "spec.json")
        if os.path.exists(spec_path):
            with open(spec_path) as f:
                spec = json.load(f)
            print(f"  {spec['moduleName']}: {spec['displayName']} ({spec['icon']})")
            print(f"    {spec['subtitle']}")
            count += 1
    if count == 0:
        print("  (no modules generated yet)")
    print(f"\nTotal: {count} module(s)")


def batch_generate(scenarios_file: str, skip_build: bool = False, use_template_views: bool = False):
    """Generate multiple modules from a JSON file."""
    with open(scenarios_file) as f:
        scenarios = json.load(f)

    results = []
    for i, scenario in enumerate(scenarios, 1):
        desc = scenario if isinstance(scenario, str) else scenario.get("description", "")
        print(f"\n[{i}/{len(scenarios)}] {desc}")
        success = generate_module(desc, skip_build=True, use_template_views=use_template_views)  # skip per-module build
        results.append({"description": desc, "success": success})

    # Single build at the end
    if not skip_build:
        print("\n" + "=" * 60)
        print("Final build with all modules...")
        print("=" * 60)
        success, errors = build_project()
        if not success:
            print(f"[FAIL] Final build failed: {errors[:1000]}")
            # Try to fix errors
            print("[FIX] Attempting batch fix...")
            # Just rebuild — individual module fixes are complex in batch mode
            for attempt in range(2):
                success, errors = build_project()
                if success:
                    break
                print(f"[FAIL] Rebuild attempt {attempt + 2} failed")

    # Summary
    print("\n" + "=" * 60)
    print("BATCH GENERATION SUMMARY")
    print("=" * 60)
    for r in results:
        status = "OK" if r["success"] else "FAIL"
        print(f"  [{status}] {r['description']}")
    succeeded = sum(1 for r in results if r["success"])
    print(f"\n{succeeded}/{len(results)} modules generated successfully")


def main():
    parser = argparse.ArgumentParser(description="Generate RyanHub dynamic modules")
    parser.add_argument("--description", "-d", help="Natural language module description")
    parser.add_argument("--batch", "-b", help="JSON file with batch scenarios")
    parser.add_argument("--list", "-l", action="store_true", help="List generated modules")
    parser.add_argument("--skip-build", action="store_true", help="Skip xcodebuild step")
    parser.add_argument("--update-bootstrap", action="store_true", help="Only update bootstrap file")
    parser.add_argument("--use-template-views", action="store_true", help="Use template views instead of Claude-generated")
    args = parser.parse_args()

    if args.list:
        list_modules()
    elif args.update_bootstrap:
        update_bootstrap()
    elif args.batch:
        batch_generate(args.batch, skip_build=args.skip_build, use_template_views=args.use_template_views)
    elif args.description:
        success = generate_module(args.description, skip_build=args.skip_build, use_template_views=args.use_template_views)
        sys.exit(0 if success else 1)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
