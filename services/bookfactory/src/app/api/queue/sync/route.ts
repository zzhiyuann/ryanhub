import { NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";
import * as fs from "fs";
import * as path from "path";

interface ParsedTopic {
  number: string; // e.g. "1", "L1"
  tier: string;
  title: string;
  status: "pending" | "done" | "skipped";
  generated_date: string | null;
  generated_slot: string | null;
}

function parseBacklog(content: string): ParsedTopic[] {
  const topics: ParsedTopic[] = [];
  let currentTier = "";
  let inPriorityQueue = false;
  let stopped = false;

  const lines = content.split("\n");

  for (const line of lines) {
    if (stopped) break;

    // Start parsing when we hit "## Priority Queue" or "## Life & Curiosity"
    if (line.match(/^##\s+Priority Queue/)) {
      inPriorityQueue = true;
      continue;
    }
    if (line.match(/^##\s+Life & Curiosity/)) {
      inPriorityQueue = true;
      continue;
    }

    // Stop parsing at "## Completed Topics" or "## User-Specified Topics"
    // These sections have different table formats and are summary/override sections
    if (line.match(/^##\s+Completed Topics/) || line.match(/^##\s+User-Specified Topics/)) {
      stopped = true;
      continue;
    }

    if (!inPriorityQueue) continue;

    // Detect tier headers like "### Tier 1: ..." or "### Tier L1: ..."
    const tierMatch = line.match(/^###\s+Tier\s+(\S+):\s*(.+)/);
    if (tierMatch) {
      currentTier = `Tier ${tierMatch[1]}`;
      continue;
    }

    // Parse table rows: | # | Topic | Status | Generated Date | Slot |
    // Skip header rows and separator rows
    if (!line.startsWith("|")) continue;
    if (line.includes("---")) continue;
    if (line.includes("| # |") || line.includes("| Topic |")) continue;

    const cells = line
      .split("|")
      .map((c) => c.trim())
      .filter((c) => c.length > 0);

    // Need at least: #, Topic, Status (5 columns expected: #, Topic, Status, Date, Slot)
    if (cells.length < 3) continue;

    const num = cells[0];
    let rawTitle = cells[1];
    const rawStatus = cells[2];

    // Skip if number doesn't look like a topic number
    if (!/^\d+$/.test(num) && !/^L\d+$/.test(num)) continue;

    // Validate status column contains a known status marker
    // This prevents parsing tables with different column layouts
    const hasStatusMarker =
      rawStatus.includes("Done") ||
      rawStatus.includes("✅") ||
      rawStatus.includes("Skipped") ||
      rawStatus.includes("❌") ||
      rawStatus.includes("Pending") ||
      rawStatus.includes("⬜");
    if (!hasStatusMarker) continue;

    // Clean title: remove strikethrough markers ~~...~~
    rawTitle = rawTitle.replace(/~~/g, "").trim();
    if (!rawTitle) continue;

    // Parse status
    let status: "pending" | "done" | "skipped";
    if (rawStatus.includes("Done") || rawStatus.includes("✅")) {
      status = "done";
    } else if (rawStatus.includes("Skipped") || rawStatus.includes("❌")) {
      status = "skipped";
    } else {
      status = "pending";
    }

    // Parse date and slot (columns 3 and 4, if they exist)
    const generatedDate = cells.length > 3 && cells[3] ? cells[3] : null;
    const generatedSlot = cells.length > 4 && cells[4] ? cells[4] : null;

    topics.push({
      number: num,
      tier: currentTier,
      title: rawTitle,
      status,
      generated_date: generatedDate,
      generated_slot: generatedSlot,
    });
  }

  return topics;
}

export async function POST() {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  // Find the backlog file
  const backlogPaths = [
    process.env.BACKLOG_PATH,
    path.join(process.cwd(), "books", "topic_backlog.md"),
  ].filter(Boolean) as string[];

  let backlogContent: string | null = null;
  for (const p of backlogPaths) {
    if (fs.existsSync(p)) {
      backlogContent = fs.readFileSync(p, "utf-8");
      break;
    }
  }

  if (!backlogContent) {
    return NextResponse.json(
      { error: "topic_backlog.md not found" },
      { status: 404 }
    );
  }

  const parsed = parseBacklog(backlogContent);
  if (parsed.length === 0) {
    return NextResponse.json(
      { error: "No topics found in backlog" },
      { status: 400 }
    );
  }

  const db = getDb();

  // Full replace: delete all existing topics for this user, then re-import
  // This ensures clean state and correct status for all topics
  const txn = db.transaction(() => {
    db.prepare(`DELETE FROM queue_topics WHERE user_id = ?`).run(user.id);

    const insertStmt = db.prepare(
      `INSERT INTO queue_topics (id, user_id, tier, title, description, status, position, generated_date, generated_slot)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    );

    for (let i = 0; i < parsed.length; i++) {
      const topic = parsed[i];
      const id = `${topic.number}_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
      insertStmt.run(
        id,
        user.id,
        topic.tier,
        topic.title,
        null,
        topic.status,
        i + 1,
        topic.generated_date,
        topic.generated_slot
      );
    }
  });

  txn();

  return NextResponse.json({
    added: parsed.length,
    updated: 0,
    total: parsed.length,
    parsed: parsed.length,
  });
}
