#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/zwang/projects/ryanhub"
DEFAULT_UDID="A6FABD75-8BE5-4ECE-B6E6-3E39FC9A3CA0"
BUNDLE_ID="com.zwang.ryanhub.RyanHub"
BRIDGE_DATA_DIR="${HOME}/.ryanhub-data"

UDID="${1:-$DEFAULT_UDID}"

if ! xcrun simctl list devices | grep -q "$UDID"; then
  echo "Simulator not found: $UDID" >&2
  exit 1
fi

APP_PATH="$(find "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path '*/Build/Products/Debug-iphonesimulator/RyanHub.app' \
  -type d -print 2>/dev/null | tail -n 1)"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  APP_PATH="$ROOT_DIR/build/Build/Products/Debug-iphonesimulator/RyanHub.app"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found in DerivedData or $APP_PATH" >&2
  echo "Run: xcodebuild -scheme RyanHub -destination 'platform=iOS Simulator,id=$UDID' build" >&2
  exit 1
fi

if [[ ! -d "$BRIDGE_DATA_DIR" ]]; then
  echo "Bridge data directory not found: $BRIDGE_DATA_DIR" >&2
  exit 1
fi

echo "Booting simulator $UDID"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true

echo "Installing app from $APP_PATH"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

APP_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
if [[ -z "$APP_CONTAINER" || ! -d "$APP_CONTAINER" ]]; then
  echo "Failed to locate app container for $BUNDLE_ID" >&2
  exit 1
fi

PREFS_DIR="$APP_CONTAINER/Library/Preferences"
DOCS_DIR="$APP_CONTAINER/Documents"
mkdir -p "$PREFS_DIR" "$DOCS_DIR/bobo/photos"

export APP_CONTAINER PREFS_DIR DOCS_DIR BRIDGE_DATA_DIR BUNDLE_ID

python3 - <<'PY'
import json
import os
import plistlib
import shutil
import time
from pathlib import Path

app_container = Path(os.environ["APP_CONTAINER"])
prefs_dir = Path(os.environ["PREFS_DIR"])
docs_dir = Path(os.environ["DOCS_DIR"])
bridge_dir = Path(os.environ["BRIDGE_DATA_DIR"])
bundle_id = os.environ["BUNDLE_ID"]
plist_path = prefs_dir / f"{bundle_id}.plist"

if plist_path.exists():
    with plist_path.open("rb") as fh:
        plist = plistlib.load(fh)
else:
    plist = {}

def set_data_key(key: str, file_name: str) -> None:
    path = bridge_dir / file_name
    if path.exists():
        plist[key] = path.read_bytes()

def set_text_key(key: str, value: str) -> None:
    plist[key] = value

def set_bool_key(key: str, value: bool) -> None:
    plist[key] = value

def set_float_key(key: str, file_name: str) -> None:
    path = bridge_dir / file_name
    if path.exists():
        try:
            plist[key] = float(path.read_text().strip())
        except ValueError:
            pass

# Core connectivity defaults
set_text_key("ryanhub_server_url", "ws://100.89.67.80:8765")
set_text_key("ryanhub_food_analysis_url", "http://100.89.67.80:18790")
set_text_key("ryanhub_calendar_sync_url", "http://100.89.67.80:18793")
set_bool_key("ryanhub_is_custom_food_analysis_url", False)
set_bool_key("ryanhub_is_custom_calendar_sync_url", False)

# Fast local cache mirrors for server-backed data
set_data_key("ryanhub_health_weight", "health_weight.json")
set_data_key("ryanhub_health_food", "health_food.json")
set_data_key("ryanhub_health_activity", "health_activity.json")
set_data_key("ryanhub_chat_messages_v2", "chat_messages.json")
set_data_key("ryanhub_bobo_narrations", "popo_narrations.json")
set_data_key("ryanhub_bobo_nudges", "popo_nudges.json")
set_float_key("ryanhub_bobo_last_nudge_generation", "popo_last_nudge_gen.txt")

# Dynamic module cache mirrors, if present on the bridge server.
for module_file in bridge_dir.glob("module_*.json"):
    module_id = module_file.stem.removeprefix("module_")
    plist[f"dynamic_module_{module_id}_cache"] = module_file.read_bytes()

# Rebuild the BOBO local documents store from bridge-server snapshots.
bobo_dir = docs_dir / "bobo"
photos_dir = bobo_dir / "photos"
bobo_dir.mkdir(parents=True, exist_ok=True)
photos_dir.mkdir(parents=True, exist_ok=True)

events_path = bridge_dir / "popo_sensing.json"
if events_path.exists():
    shutil.copy2(events_path, bobo_dir / "bobo_events.json")
    try:
        events = json.loads(events_path.read_text())
        synced_ids = [event["id"] for event in events if isinstance(event, dict) and "id" in event]
        (bobo_dir / "bobo_synced_ids.json").write_text(json.dumps(synced_ids))
        plist["ryanhub_bobo_last_sync_time"] = time.time()
    except Exception:
        (bobo_dir / "bobo_synced_ids.json").write_text("[]")

photos_src = bridge_dir / "popo_photos"
if photos_src.exists():
    for file in photos_src.rglob("*.jpg"):
        shutil.copy2(file, photos_dir / file.name)

with plist_path.open("wb") as fh:
    plistlib.dump(plist, fh, fmt=plistlib.FMT_BINARY)
PY

echo "Launching app"
xcrun simctl launch "$UDID" "$BUNDLE_ID"
echo "Seeded simulator container: $APP_CONTAINER"
