#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import uuid
from collections import defaultdict
from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


DATA_DIR = Path.home() / ".ryanhub-data"
BACKUP_ROOT = Path.home() / ".ryanhub-data-backups"


def now_stamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def iso_at(day: str, hour: int, minute: int) -> str:
    return f"{day}T{hour:02d}:{minute:02d}:00Z"


def new_id() -> str:
    return str(uuid.uuid4()).upper()


def load_json(path: Path):
    with path.open() as fh:
        return json.load(fh)


def save_json(path: Path, data) -> None:
    with path.open("w") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def backup_files(files: list[Path]) -> Path:
    backup_dir = BACKUP_ROOT / f"demo-fill-{now_stamp()}"
    backup_dir.mkdir(parents=True, exist_ok=True)
    for src in files:
        shutil.copy2(src, backup_dir / src.name)
    return backup_dir


def existing_count(items: list[dict], key: str) -> dict[str, int]:
    counts: dict[str, int] = defaultdict(int)
    for item in items:
        value = item.get(key, "")
        if isinstance(value, str) and len(value) >= 10:
            counts[value[:10]] += 1
    return counts


def add_if_missing_day(items: list[dict], key: str, additions: list[dict], max_existing: int) -> int:
    counts = existing_count(items, key)
    added = 0
    for item in additions:
        day = item[key][:10]
        if counts[day] < max_existing:
            items.append(item)
            counts[day] += 1
            added += 1
    return added


def food_entry(day: str, hour: int, minute: int, meal_type: str, description: str,
               calories: int, protein: int, carbs: int, fat: int, summary: str) -> dict:
    return {
        "id": new_id(),
        "date": iso_at(day, hour, minute),
        "mealType": meal_type,
        "description": description,
        "calories": calories,
        "protein": protein,
        "carbs": carbs,
        "fat": fat,
        "isAIAnalyzed": True,
        "aiSummary": summary,
    }


def activity_entry(day: str, hour: int, minute: int, activity_type: str, duration: int,
                   raw_description: str, calories: int | None = None, note: str | None = None) -> dict:
    item = {
        "id": new_id(),
        "date": iso_at(day, hour, minute),
        "type": activity_type,
        "duration": duration,
        "rawDescription": raw_description,
        "note": note or raw_description,
        "exercises": [],
        "isAIAnalyzed": False,
    }
    if calories is not None:
        item["caloriesBurned"] = calories
    return item


def weight_entry(day: str, hour: int, minute: int, weight: float) -> dict:
    return {
        "id": new_id(),
        "date": iso_at(day, hour, minute),
        "weight": weight,
    }


def sensing_event(day: str, hour: int, minute: int, modality: str, payload: dict[str, str]) -> dict:
    return {
        "id": new_id(),
        "timestamp": iso_at(day, hour, minute),
        "modality": modality,
        "payload": payload,
    }


def place_payload(label: str, place_name: str, place_type: str, address: str,
                  lat: str, lon: str) -> dict[str, str]:
    return {
        "semanticLabel": label,
        "placeName": place_name,
        "placeType": place_type,
        "address": address,
        "latitude": lat,
        "longitude": lon,
        "enriched": "true",
        "city": "Charlottesville",
        "neighborhood": "",
    }


def audit_summary(food: list[dict], activity: list[dict], weight: list[dict],
                  sensing: list[dict], narrations: list[dict], nudges: list[dict]) -> dict:
    days = [f"2026-03-0{idx}" for idx in range(1, 8)]
    per_day = {}
    sensing_sources: dict[str, dict[str, int]] = {}

    for day in days:
        day_sensing = [item for item in sensing if item.get("timestamp", "").startswith(day)]
        source_counts: dict[str, int] = defaultdict(int)
        for item in day_sensing:
            payload = item.get("payload", {})
            source = payload.get("source") or "native_or_unspecified"
            source_counts[source] += 1

        sensing_sources[day] = dict(sorted(source_counts.items()))
        per_day[day] = {
            "food": sum(1 for item in food if item.get("date", "").startswith(day)),
            "activity": sum(1 for item in activity if item.get("date", "").startswith(day)),
            "weight": sum(1 for item in weight if item.get("date", "").startswith(day)),
            "narration": sum(1 for item in narrations if item.get("timestamp", "").startswith(day)),
            "nudge": sum(1 for item in nudges if item.get("timestamp", "").startswith(day)),
            "sensing": len(day_sensing),
        }

    return {
        "totals": {
            "food": len(food),
            "activity": len(activity),
            "weight": len(weight),
            "narration": len(narrations),
            "nudge": len(nudges),
            "sensing": len(sensing),
        },
        "perDay": per_day,
        "sensingSources": sensing_sources,
    }


FOOD_ADDITIONS = [
    food_entry("2026-03-01", 13, 5, "lunch", "Beef noodle soup and milk tea after getting out",
               680, 29, 83, 15, "A beef noodle lunch with milk tea, matching a heavier midday meal."),
    food_entry("2026-03-01", 20, 0, "dinner", "Chicken curry rice with one egg",
               550, 24, 58, 18, "Chicken curry rice with egg, a compact dinner after a light day."),
    food_entry("2026-03-03", 12, 20, "breakfast", "Two sandwiches with fried eggs and ham",
               620, 34, 46, 28, "Two sandwiches with egg and ham, similar to the recurring breakfast pattern."),
    food_entry("2026-03-03", 20, 10, "dinner", "Beef noodle soup after gym",
               550, 36, 61, 15, "A beef noodle dinner after an evening workout."),
    food_entry("2026-03-04", 19, 20, "dinner", "Chicken curry rice with one egg",
               550, 24, 58, 18, "Chicken curry rice added to round out an otherwise breakfast-only day."),
    food_entry("2026-03-05", 13, 10, "lunch", "Two ham hamburgers and blueberries",
               960, 32, 112, 34, "A heavier lunch with two ham burgers and fruit."),
    food_entry("2026-03-05", 20, 5, "dinner", "Grilled beef steak with pesto pasta and fresh vegetables",
               655, 42, 51, 26, "Steak, pasta, and vegetables for dinner."),
    food_entry("2026-03-06", 20, 55, "dinner", "Beef noodle and milk tea",
               680, 29, 83, 15, "A beef noodle dinner with milk tea."),
    food_entry("2026-03-07", 12, 30, "breakfast", "Two sandwiches with fried eggs and ham",
               620, 34, 46, 28, "A familiar sandwich breakfast."),
    food_entry("2026-03-07", 20, 0, "dinner", "Chicken curry rice and one egg",
               550, 24, 58, 18, "Chicken curry rice for dinner after a long day."),
]


ACTIVITY_ADDITIONS = [
    activity_entry("2026-03-01", 17, 40, "Walking", 42, "Walked across campus and back in the afternoon", 190),
    activity_entry("2026-03-03", 18, 35, "Gym", 48, "Upper body session at AFC: pulldown, rows, cable work", 310),
    activity_entry("2026-03-05", 18, 50, "Gym", 38, "Short gym session after work: chest press and cable rows", 250),
    activity_entry("2026-03-07", 18, 20, "Gym", 52, "Evening gym session with legs and accessories", 360),
]


WEIGHT_ADDITIONS = [
    weight_entry("2026-03-02", 8, 10, 89.0),
    weight_entry("2026-03-05", 8, 5, 88.7),
    weight_entry("2026-03-07", 8, 15, 88.5),
]


SENSING_ADDITIONS = [
    # 2026-03-01
    sensing_event("2026-03-01", 9, 5, "battery", {"level": "86", "state": "unplugged"}),
    sensing_event("2026-03-01", 9, 20, "screen", {"state": "hourly_aggregate", "count": "5", "totalDuration": "4200"}),
    sensing_event("2026-03-01", 11, 45, "location", place_payload("Home", "Apartment", "residence", "Charlottesville, VA", "38.0319", "-78.4769")),
    sensing_event("2026-03-01", 12, 15, "motion", {"activityType": "walking", "confidence": "high", "duration": "1800", "nextActivity": "stationary", "source": "demo_backfill"}),
    sensing_event("2026-03-01", 13, 10, "steps", {"steps": "4630", "distance": "3380", "source": "demo_backfill"}),
    sensing_event("2026-03-01", 13, 12, "heartRate", {"bpm": "84", "min": "79", "max": "92", "count": "3", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-01", 13, 20, "bluetooth", {"deviceCount": "16", "namedCount": "4", "scanDuration": "10"}),
    sensing_event("2026-03-01", 18, 5, "location", place_payload("", "UVA School of Education and Human Development", "university", "405 Emmet St S, Charlottesville, VA 22903, USA", "38.034529", "-78.509273")),
    sensing_event("2026-03-01", 20, 30, "wifi", {"ssid": "disconnected", "connected": "false", "source": "demo_backfill"}),
    sensing_event("2026-03-01", 21, 15, "activeEnergy", {"kcal": "286", "hourLabel": "6PM-9PM", "source": "Zhiyuan’s Apple Watch"}),

    # 2026-03-02
    sensing_event("2026-03-02", 8, 40, "battery", {"level": "91", "state": "unplugged"}),
    sensing_event("2026-03-02", 10, 10, "location", place_payload("Home", "Apartment", "residence", "Charlottesville, VA", "38.0319", "-78.4769")),
    sensing_event("2026-03-02", 12, 55, "steps", {"steps": "6120", "distance": "4480", "source": "demo_backfill"}),
    sensing_event("2026-03-02", 13, 15, "screen", {"state": "hourly_aggregate", "count": "7", "totalDuration": "5400"}),
    sensing_event("2026-03-02", 16, 45, "location", place_payload("", "UVA School of Education and Human Development", "university", "405 Emmet St S, Charlottesville, VA 22903, USA", "38.034529", "-78.509273")),
    sensing_event("2026-03-02", 17, 0, "motion", {"activityType": "walking", "confidence": "high", "duration": "2100", "nextActivity": "stationary", "source": "demo_backfill"}),
    sensing_event("2026-03-02", 17, 2, "workout", {"type": "walking", "duration": "3600", "calories": "183", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-02", 17, 10, "heartRate", {"bpm": "96", "min": "88", "max": "111", "count": "4", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-02", 18, 10, "bluetooth", {"deviceCount": "18", "namedCount": "5", "scanDuration": "10"}),
    sensing_event("2026-03-02", 19, 5, "activeEnergy", {"kcal": "342", "hourLabel": "4PM-7PM", "source": "Zhiyuan’s Apple Watch"}),

    # 2026-03-03
    sensing_event("2026-03-03", 8, 35, "battery", {"level": "88", "state": "unplugged"}),
    sensing_event("2026-03-03", 11, 50, "location", place_payload("", "UVA School of Education and Human Development", "university", "405 Emmet St S, Charlottesville, VA 22903, USA", "38.034529", "-78.509273")),
    sensing_event("2026-03-03", 12, 0, "screen", {"state": "hourly_aggregate", "count": "6", "totalDuration": "5100"}),
    sensing_event("2026-03-03", 12, 45, "steps", {"steps": "5380", "distance": "3950", "source": "demo_backfill"}),
    sensing_event("2026-03-03", 13, 0, "motion", {"activityType": "stationary", "confidence": "high", "duration": "9600", "nextActivity": "walking", "source": "demo_backfill"}),
    sensing_event("2026-03-03", 18, 25, "location", place_payload("Gym", "AFC", "gym", "118 Student Health Rd, Charlottesville, VA 22903, USA", "38.0337", "-78.5108")),
    sensing_event("2026-03-03", 18, 35, "workout", {"type": "strength training", "duration": "2880", "calories": "310", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-03", 18, 50, "heartRate", {"bpm": "118", "min": "102", "max": "136", "count": "5", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-03", 19, 40, "activeEnergy", {"kcal": "401", "hourLabel": "6PM-8PM", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-03", 21, 30, "wifi", {"ssid": "disconnected", "connected": "false", "source": "demo_backfill"}),

    # 2026-03-04
    sensing_event("2026-03-04", 8, 50, "battery", {"level": "84", "state": "unplugged"}),
    sensing_event("2026-03-04", 11, 55, "location", place_payload("", "UVA School of Education and Human Development", "university", "405 Emmet St S, Charlottesville, VA 22903, USA", "38.034529", "-78.509273")),
    sensing_event("2026-03-04", 12, 10, "screen", {"state": "hourly_aggregate", "count": "8", "totalDuration": "5700"}),
    sensing_event("2026-03-04", 13, 5, "steps", {"steps": "5840", "distance": "4230", "source": "demo_backfill"}),
    sensing_event("2026-03-04", 16, 30, "motion", {"activityType": "walking", "confidence": "high", "duration": "1200", "nextActivity": "stationary", "source": "demo_backfill"}),
    sensing_event("2026-03-04", 17, 45, "location", place_payload("Gym", "AFC", "gym", "118 Student Health Rd, Charlottesville, VA 22903, USA", "38.0337", "-78.5108")),
    sensing_event("2026-03-04", 18, 0, "workout", {"type": "gym", "duration": "2760", "calories": "295", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-04", 18, 5, "heartRate", {"bpm": "112", "min": "101", "max": "129", "count": "4", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-04", 19, 10, "activeEnergy", {"kcal": "372", "hourLabel": "5PM-7PM", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-04", 22, 5, "bluetooth", {"deviceCount": "19", "namedCount": "5", "scanDuration": "10"}),

    # 2026-03-05
    sensing_event("2026-03-05", 8, 30, "battery", {"level": "82", "state": "unplugged"}),
    sensing_event("2026-03-05", 10, 30, "screen", {"state": "hourly_aggregate", "count": "4", "totalDuration": "3300"}),
    sensing_event("2026-03-05", 12, 40, "location", place_payload("", "UVA School of Education and Human Development", "university", "405 Emmet St S, Charlottesville, VA 22903, USA", "38.034529", "-78.509273")),
    sensing_event("2026-03-05", 13, 15, "steps", {"steps": "5050", "distance": "3660", "source": "demo_backfill"}),
    sensing_event("2026-03-05", 13, 25, "motion", {"activityType": "walking", "confidence": "high", "duration": "900", "nextActivity": "stationary", "source": "demo_backfill"}),
    sensing_event("2026-03-05", 18, 45, "location", place_payload("Gym", "AFC", "gym", "118 Student Health Rd, Charlottesville, VA 22903, USA", "38.0337", "-78.5108")),
    sensing_event("2026-03-05", 18, 50, "workout", {"type": "gym", "duration": "2280", "calories": "250", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-05", 19, 5, "heartRate", {"bpm": "109", "min": "98", "max": "125", "count": "4", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-05", 19, 20, "activeEnergy", {"kcal": "318", "hourLabel": "6PM-8PM", "source": "Zhiyuan’s Apple Watch"}),
    sensing_event("2026-03-05", 21, 55, "wifi", {"ssid": "disconnected", "connected": "false", "source": "demo_backfill"}),

    # 2026-03-06 (light enrichment only)
    sensing_event("2026-03-06", 18, 10, "screen", {"state": "hourly_aggregate", "count": "6", "totalDuration": "4500"}),
    sensing_event("2026-03-06", 18, 12, "bluetooth", {"deviceCount": "16", "namedCount": "4", "scanDuration": "10"}),
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", action="store_true", help="Print coverage without modifying data.")
    args = parser.parse_args()

    food_path = DATA_DIR / "health_food.json"
    activity_path = DATA_DIR / "health_activity.json"
    weight_path = DATA_DIR / "health_weight.json"
    sensing_path = DATA_DIR / "popo_sensing.json"
    narration_path = DATA_DIR / "popo_narrations.json"
    nudge_path = DATA_DIR / "popo_nudges.json"

    food = load_json(food_path)
    activity = load_json(activity_path)
    weight = load_json(weight_path)
    sensing = load_json(sensing_path)
    narrations = load_json(narration_path)
    nudges = load_json(nudge_path)

    if args.audit:
        print(json.dumps(audit_summary(food, activity, weight, sensing, narrations, nudges), indent=2))
        return

    files = [food_path, activity_path, weight_path, sensing_path]
    backup_dir = backup_files(files)

    added_food = add_if_missing_day(food, "date", FOOD_ADDITIONS, max_existing=2)
    added_activity = add_if_missing_day(activity, "date", ACTIVITY_ADDITIONS, max_existing=1)
    added_weight = add_if_missing_day(weight, "date", WEIGHT_ADDITIONS, max_existing=1)

    sensing_counts = existing_count(sensing, "timestamp")
    added_sensing = 0
    for item in SENSING_ADDITIONS:
        day = item["timestamp"][:10]
        target = 8 if day != "2026-03-06" else 66
        if sensing_counts[day] < target:
            sensing.append(item)
            sensing_counts[day] += 1
            added_sensing += 1

    save_json(food_path, sorted(food, key=lambda x: x["date"]))
    save_json(activity_path, sorted(activity, key=lambda x: x["date"]))
    save_json(weight_path, sorted(weight, key=lambda x: x["date"]))
    save_json(sensing_path, sorted(sensing, key=lambda x: x["timestamp"]))

    print(json.dumps({
        "backupDir": str(backup_dir),
        "added": {
            "food": added_food,
            "activity": added_activity,
            "weight": added_weight,
            "sensing": added_sensing,
        }
    }, indent=2))


if __name__ == "__main__":
    main()
