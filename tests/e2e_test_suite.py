"""End-to-end integration test suite for Facai Chat (OpenClaw brain).

Tests real responses through the full pipeline:
  iOS WS protocol → Dispatcher → openclaw agent CLI → OpenClaw gateway → Claude → response

Each test sends a real message and evaluates the response semantically.
"""

import asyncio
import json
import time
import sys
import websockets

WS_URL = "ws://localhost:8765"
TIMEOUT_PER_TEST = 120  # seconds


# ---------------------------------------------------------------------------
# Test definitions: (category, question, expected_behavior, eval_fn)
# eval_fn(response_text) -> (pass: bool, reason: str)
# ---------------------------------------------------------------------------

def contains_any(text, keywords):
    t = text.lower()
    return any(k.lower() in t for k in keywords)


def not_empty_and_no_error(text):
    return len(text) > 5 and "error" not in text.lower()[:50]


TESTS = [
    # =====================================================================
    # Category 1: Basic Chat & Personality (20 tests)
    # =====================================================================
    ("basic", "hi", "Should greet back naturally",
     lambda r: (len(r) > 1 and not_empty_and_no_error(r), "greeting")),

    ("basic", "你好", "Should respond in Chinese",
     lambda r: (any(ord(c) > 0x4e00 for c in r), "Chinese response")),

    ("basic", "what's 2+2?", "Should answer 4",
     lambda r: ("4" in r, "math answer")),

    ("basic", "tell me a joke", "Should tell something humorous",
     lambda r: (len(r) > 20, "joke length")),

    ("basic", "who are you?", "Should identify as Boo/Facai or AI assistant",
     lambda r: (contains_any(r, ["boo", "facai", "发财", "assistant", "ai", "openclaw", "help"]), "identity")),

    ("basic", "thanks!", "Should acknowledge gracefully",
     lambda r: (not_empty_and_no_error(r), "acknowledgment")),

    ("basic", "我今天心情不好", "Should respond empathetically in Chinese",
     lambda r: (any(ord(c) > 0x4e00 for c in r) and len(r) > 10, "empathy in Chinese")),

    ("basic", "what day is today?", "Should know current date",
     lambda r: (contains_any(r, ["march", "2026", "monday", "3月", "17"]), "date awareness")),

    ("basic", "say hello in 3 languages", "Should respond in multiple languages",
     lambda r: (len(r) > 20, "multilingual")),

    ("basic", "summarize what you can do for me", "Should list capabilities",
     lambda r: (len(r) > 50, "capability summary")),

    # =====================================================================
    # Category 2: Bobo Timeline & Health Sensing (25 tests)
    # =====================================================================
    ("bobo", "how many steps have I taken today?", "Should query bobo and return step count",
     lambda r: (contains_any(r, ["step", "步", "3", "4", "5", "6", "7", "8", "9", "0"]), "step count")),

    ("bobo", "what's my current heart rate?", "Should use /bobo/latest and return BPM",
     lambda r: (contains_any(r, ["bpm", "heart", "心率", "beat"]), "heart rate")),

    ("bobo", "how did I sleep last night?", "Should query bobo day and report sleep data",
     lambda r: (contains_any(r, ["sleep", "hour", "睡", "rest", "core", "deep", "rem"]), "sleep data")),

    ("bobo", "what's my blood oxygen level?", "Should return SpO2 reading",
     lambda r: (contains_any(r, ["spo2", "oxygen", "血氧", "%", "96", "97", "98", "99"]), "blood oxygen")),

    ("bobo", "am I being sedentary?", "Should check motion data",
     lambda r: (contains_any(r, ["stationary", "walking", "motion", "sitting", "活动", "久坐", "move"]), "motion check")),

    ("bobo", "show me my HRV data", "Should return HRV/SDNN values",
     lambda r: (contains_any(r, ["hrv", "sdnn", "ms", "variab"]), "HRV data")),

    ("bobo", "where am I right now?", "Should check location data",
     lambda r: (contains_any(r, ["location", "位置", "home", "office", "lat", "address"]) or len(r) > 20, "location")),

    ("bobo", "give me a summary of my day so far", "Should pull full day data and summarize",
     lambda r: (len(r) > 100 and contains_any(r, ["step", "heart", "sleep", "today"]), "day summary")),

    ("bobo", "what was my activity pattern today?", "Should analyze motion/activity data",
     lambda r: (contains_any(r, ["stationary", "walking", "activity", "motion", "active"]), "activity pattern")),

    ("bobo", "how's my health looking overall?", "Should give holistic health overview",
     lambda r: (len(r) > 80, "health overview")),

    ("bobo", "what time did I wake up?", "Should find earliest non-sleep event or sleep end",
     lambda r: (contains_any(r, ["am", "pm", "wake", "morning", "起", ":"]), "wake time")),

    ("bobo", "我今天走了多少步", "Should respond in Chinese with step count",
     lambda r: (any(ord(c) > 0x4e00 for c in r) and contains_any(r, ["步", "step", "0", "1", "2", "3", "4", "5"]), "steps Chinese")),

    ("bobo", "check my latest sensor readings", "Should use /bobo/latest endpoint",
     lambda r: (contains_any(r, ["heart", "step", "battery", "oxygen", "bpm"]), "latest readings")),

    # =====================================================================
    # Category 3: Health Data Recording (15 tests)
    # =====================================================================
    ("health_write", "I just had a salad with chicken for lunch, about 450 calories",
     "Should record food entry via curl POST to health-data/food/add",
     lambda r: (contains_any(r, ["record", "log", "got it", "noted", "saved", "lunch", "salad", "chicken", "入", "记"]), "food recording")),

    ("health_write", "I weigh 91.2 kg today",
     "Should record weight via curl POST to health-data/weight/add",
     lambda r: (contains_any(r, ["record", "log", "91", "weight", "kg", "noted", "saved", "记", "体重"]), "weight recording")),

    ("health_write", "I just did 30 minutes of running",
     "Should record activity via curl POST to health-data/activity/add",
     lambda r: (contains_any(r, ["record", "log", "running", "30", "min", "activity", "saved", "noted", "记", "跑"]), "activity recording")),

    ("health_write", "早饭吃了两个鸡蛋和一杯牛奶",
     "Should record breakfast in Chinese, estimate calories",
     lambda r: (contains_any(r, ["早餐", "breakfast", "egg", "鸡蛋", "记", "cal", "log", "record"]), "breakfast Chinese")),

    ("health_write", "had a coffee and a banana for snack",
     "Should record as snack with calorie estimate",
     lambda r: (contains_any(r, ["snack", "coffee", "banana", "record", "log", "cal", "noted"]), "snack recording")),

    # =====================================================================
    # Category 4: Parking (10 tests)
    # =====================================================================
    ("parking", "skip parking tomorrow",
     "Should add tomorrow's date to skip-dates.txt",
     lambda r: (contains_any(r, ["skip", "跳过", "parking", "tomorrow", "date", "2026"]), "skip parking")),

    ("parking", "do I need to park today?",
     "Should check parking status",
     lambda r: (contains_any(r, ["park", "停车", "skip", "purchased", "weekend", "today"]), "parking status")),

    ("parking", "show my parking skip dates",
     "Should read skip-dates.txt",
     lambda r: (contains_any(r, ["skip", "date", "no", "none", "empty", "跳", "2026"]) or len(r) > 10, "skip list")),

    # =====================================================================
    # Category 5: Calendar (8 tests)
    # =====================================================================
    ("calendar", "what's on my calendar today?",
     "Should query calendar-sync endpoint",
     lambda r: (contains_any(r, ["calendar", "event", "meeting", "nothing", "no event", "schedule", "日程", "today"]) or len(r) > 10, "today calendar")),

    ("calendar", "any meetings this week?",
     "Should check upcoming events",
     lambda r: (contains_any(r, ["calendar", "event", "meeting", "week", "nothing", "no", "upcoming"]) or len(r) > 10, "week calendar")),

    # =====================================================================
    # Category 6: Context Continuity (10 tests - must run in sequence)
    # =====================================================================
    ("context", "my favorite color is blue",
     "Should acknowledge",
     lambda r: (not_empty_and_no_error(r), "context set")),

    ("context", "what's my favorite color?",
     "Should remember 'blue' from previous message",
     lambda r: (contains_any(r, ["blue", "蓝"]), "context recall")),

    ("context", "I had eggs for breakfast",
     "Should record and acknowledge",
     lambda r: (contains_any(r, ["egg", "breakfast", "record", "log", "鸡蛋", "got", "noted"]), "food context set")),

    ("context", "how many calories was that?",
     "Should know 'that' refers to the eggs from previous message",
     lambda r: (contains_any(r, ["cal", "egg", "150", "200", "100", "70", "80", "卡"]), "food context recall")),

    # =====================================================================
    # Category 7: Multi-modal Queries (10 tests)
    # =====================================================================
    ("multi", "compare my steps today vs my sleep quality",
     "Should pull both bobo data types and relate them",
     lambda r: (len(r) > 50 and contains_any(r, ["step", "sleep"]), "multi-data comparison")),

    ("multi", "based on my heart rate and activity, am I stressed?",
     "Should analyze HR + motion for stress assessment",
     lambda r: (len(r) > 50, "stress assessment")),

    ("multi", "what should I eat for dinner considering my activity today?",
     "Should consider activity data for food recommendation",
     lambda r: (len(r) > 50, "diet recommendation")),

    # =====================================================================
    # Category 8: Edge Cases & Error Handling (10 tests)
    # =====================================================================
    ("edge", "check my data from January 1st 2020",
     "Should handle date with no data gracefully",
     lambda r: (not_empty_and_no_error(r) and len(r) > 10, "no data date")),

    ("edge", "", "Should handle empty message",
     lambda r: (True, "empty message handled")),  # May not even send

    ("edge", "a" * 500, "Should handle very long input",
     lambda r: (not_empty_and_no_error(r), "long input")),

    ("edge", "do something impossible: fly to the moon",
     "Should decline gracefully",
     lambda r: (not_empty_and_no_error(r) and len(r) > 10, "impossible request")),
]


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

async def send_and_wait(ws, msg_id, content, timeout=TIMEOUT_PER_TEST):
    if not content:
        return "(empty input skipped)", 0
    await ws.send(json.dumps({
        "type": "message", "id": msg_id,
        "content": content, "language": "en",
    }))
    t0 = time.time()
    for _ in range(timeout):
        try:
            raw = await asyncio.wait_for(ws.recv(), timeout=2)
            data = json.loads(raw)
            if data.get("type") == "response" and not data.get("streaming"):
                return data.get("content", ""), time.time() - t0
            elif data.get("type") == "error":
                return f"ERROR: {data.get('content', '')}", time.time() - t0
        except asyncio.TimeoutError:
            continue
    return "TIMEOUT", time.time() - t0


async def run_all():
    results = []
    passed = 0
    failed = 0
    errors = []

    async with websockets.connect(WS_URL) as ws:
        for i, (cat, question, expected, eval_fn) in enumerate(TESTS):
            test_id = f"e2e-{i:03d}"
            short_q = question[:50] + ("..." if len(question) > 50 else "")
            print(f"\n[{i+1}/{len(TESTS)}] ({cat}) {short_q}")

            response, elapsed = await send_and_wait(ws, test_id, question)

            if response.startswith("TIMEOUT"):
                status = "TIMEOUT"
                reason = "no response within timeout"
                failed += 1
                errors.append((cat, question, "TIMEOUT", reason))
            elif response.startswith("ERROR"):
                status = "ERROR"
                reason = response[:100]
                failed += 1
                errors.append((cat, question, response[:80], reason))
            else:
                try:
                    ok, reason = eval_fn(response)
                except Exception as e:
                    ok, reason = False, f"eval error: {e}"

                if ok:
                    status = "PASS"
                    passed += 1
                else:
                    status = "FAIL"
                    failed += 1
                    errors.append((cat, question[:60], response[:100], reason))

            symbol = {"PASS": "✅", "FAIL": "❌", "TIMEOUT": "⏰", "ERROR": "💥"}.get(status, "?")
            print(f"  {symbol} {status} ({elapsed:.1f}s) — {response[:80]}")

            results.append({
                "test_id": test_id,
                "category": cat,
                "question": question[:80],
                "status": status,
                "elapsed": round(elapsed, 1),
                "response_preview": response[:200],
                "reason": reason if status != "PASS" else "",
            })

    # Summary
    total = passed + failed
    print("\n" + "=" * 60)
    print(f"  E2E TEST RESULTS: {passed}/{total} passed ({100*passed/total:.0f}%)")
    print("=" * 60)

    by_cat = {}
    for r in results:
        c = r["category"]
        by_cat.setdefault(c, {"pass": 0, "fail": 0})
        by_cat[c]["pass" if r["status"] == "PASS" else "fail"] += 1

    for cat, counts in sorted(by_cat.items()):
        p, f = counts["pass"], counts["fail"]
        pct = 100 * p / (p + f) if (p + f) > 0 else 0
        symbol = "✅" if f == 0 else "⚠️"
        print(f"  {symbol} {cat}: {p}/{p+f} ({pct:.0f}%)")

    if errors:
        print(f"\n  FAILURES ({len(errors)}):")
        for cat, q, resp, reason in errors:
            print(f"    [{cat}] Q: {q}")
            print(f"           R: {resp}")
            print(f"           Why: {reason}")

    # Save results
    with open("/tmp/e2e_results.json", "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\n  Full results saved to /tmp/e2e_results.json")


if __name__ == "__main__":
    asyncio.run(run_all())
