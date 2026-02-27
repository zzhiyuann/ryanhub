/**
 * Book Scheduler — generates books at calculated times throughout the day.
 *
 * Based on books_per_day, calculates exact trigger times (evenly spaced),
 * then sets timers to fire at those times. No polling.
 *
 * Example: books_per_day = 4 → triggers at 00:00, 06:00, 12:00, 18:00
 * Example: books_per_day = 8 → triggers at 00:00, 03:00, 06:00, ...
 *
 * Recalculates at midnight for the next day.
 */

import { getDb } from "./db";
import { startGeneration, listJobs } from "./book-generator";

let scheduledTimers: ReturnType<typeof setTimeout>[] = [];
let midnightTimer: ReturnType<typeof setTimeout> | null = null;

/** Get books_per_day for the first user */
function getBooksPerDay(): number {
  const db = getDb();
  const settings = db
    .prepare(
      "SELECT books_per_day FROM settings WHERE user_id = (SELECT id FROM users LIMIT 1)"
    )
    .get() as { books_per_day: number } | undefined;
  return settings?.books_per_day || 0;
}

/** Get user ID */
function getUserId(): string | null {
  const db = getDb();
  const user = db.prepare("SELECT id FROM users LIMIT 1").get() as
    | { id: string }
    | undefined;
  return user?.id || null;
}

/** Calculate trigger times for today (as ms offsets from now) */
function calculateTriggerTimes(booksPerDay: number): Date[] {
  if (booksPerDay <= 0) return [];

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const intervalMs = (24 * 60 * 60 * 1000) / booksPerDay;

  const times: Date[] = [];
  for (let i = 0; i < booksPerDay; i++) {
    const triggerTime = new Date(today.getTime() + i * intervalMs);
    // Only schedule future times
    if (triggerTime > now) {
      times.push(triggerTime);
    }
  }
  return times;
}

/** Pick the next topic and generate */
function triggerGeneration(): void {
  try {
    const userId = getUserId();
    if (!userId) return;

    // Check if already running
    const runningJobs = listJobs().filter((j) => j.status === "running");
    if (runningJobs.length > 0) {
      console.log(
        `[Scheduler] Skipping — already running: "${runningJobs[0].topic}"`
      );
      return;
    }

    // Check daily limit
    const db = getDb();
    const today = new Date().toISOString().slice(0, 10);
    const booksPerDay = getBooksPerDay();
    const generated = db
      .prepare(
        "SELECT COUNT(*) as cnt FROM books WHERE user_id = ? AND date = ?"
      )
      .get(userId, today) as { cnt: number };

    if (generated.cnt >= booksPerDay) {
      console.log(
        `[Scheduler] Daily limit reached (${generated.cnt}/${booksPerDay})`
      );
      return;
    }

    // Pick next pending topic
    const nextTopic = db
      .prepare(
        "SELECT id, title FROM queue_topics WHERE user_id = ? AND status = 'pending' ORDER BY position ASC LIMIT 1"
      )
      .get(userId) as { id: string; title: string } | undefined;

    if (!nextTopic) {
      console.log("[Scheduler] No pending topics in queue");
      return;
    }

    console.log(`[Scheduler] Generating: "${nextTopic.title}"`);

    db.prepare(
      "UPDATE queue_topics SET status = 'generating' WHERE id = ?"
    ).run(nextTopic.id);

    startGeneration(userId, nextTopic.title, nextTopic.id);
  } catch (e) {
    console.error("[Scheduler] Error:", e);
  }
}

/** Schedule all remaining triggers for today */
function scheduleToday(): void {
  // Clear any existing timers
  for (const timer of scheduledTimers) clearTimeout(timer);
  scheduledTimers = [];

  const booksPerDay = getBooksPerDay();
  if (booksPerDay <= 0) {
    console.log("[Scheduler] Generation disabled (books_per_day = 0)");
    return;
  }

  const triggers = calculateTriggerTimes(booksPerDay);
  const now = new Date();

  for (const triggerTime of triggers) {
    const delayMs = triggerTime.getTime() - now.getTime();
    const timer = setTimeout(() => {
      const timeStr = new Date().toLocaleTimeString("en-US", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
      console.log(`[Scheduler] Timer fired at ${timeStr}`);
      triggerGeneration();
    }, delayMs);
    scheduledTimers.push(timer);
  }

  if (triggers.length > 0) {
    const timeStrs = triggers.map((t) =>
      t.toLocaleTimeString("en-US", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      })
    );
    console.log(
      `[Scheduler] ${booksPerDay} books/day — ${triggers.length} remaining today at: ${timeStrs.join(", ")}`
    );
  } else {
    console.log(
      `[Scheduler] ${booksPerDay} books/day — all slots for today have passed`
    );
  }
}

/** Schedule midnight recalculation */
function scheduleMidnightReset(): void {
  if (midnightTimer) clearTimeout(midnightTimer);

  const now = new Date();
  const tomorrow = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate() + 1
  );
  // Add 30 seconds buffer past midnight
  const delayMs = tomorrow.getTime() - now.getTime() + 30_000;

  midnightTimer = setTimeout(() => {
    console.log("[Scheduler] Midnight reset — rescheduling for new day");
    scheduleToday();
    scheduleMidnightReset(); // Set up next midnight
  }, delayMs);
}

export function startScheduler(): void {
  scheduleToday();
  scheduleMidnightReset();
  console.log("[Scheduler] Started");
}

export function stopScheduler(): void {
  for (const timer of scheduledTimers) clearTimeout(timer);
  scheduledTimers = [];
  if (midnightTimer) {
    clearTimeout(midnightTimer);
    midnightTimer = null;
  }
  console.log("[Scheduler] Stopped");
}

/** Force reschedule (call when books_per_day changes) */
export function reschedule(): void {
  console.log("[Scheduler] Rescheduling...");
  scheduleToday();
}
