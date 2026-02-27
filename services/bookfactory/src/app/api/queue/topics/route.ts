import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";
import { writeBacklogToFile } from "@/lib/backlog-sync";
import { startGeneration } from "@/lib/book-generator";
import { v4 as uuidv4 } from "uuid";

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { title, tier, description, scheduling } = await req.json();

  if (!title) {
    return NextResponse.json({ error: "Title required" }, { status: 400 });
  }

  const db = getDb();
  const schedule = scheduling || "End of Queue";

  // Wrap position shift + insert in a transaction to prevent race conditions
  const insertTopic = db.transaction(() => {
    let insertPosition: number;

    if (schedule === "Generate Now" || schedule === "Today") {
      // Insert at position 0 (top of queue) — will be next to generate
      insertPosition = 0;
      // Shift all existing pending topics down
      db.prepare(
        `UPDATE queue_topics SET position = position + 1 WHERE user_id = ? AND status = 'pending'`
      ).run(user.id);
    } else if (schedule === "Tomorrow") {
      // Insert after today's remaining slots
      const settings = db
        .prepare(`SELECT books_per_day FROM settings WHERE user_id = ?`)
        .get(user.id) as { books_per_day: number } | undefined;
      const booksPerDay = settings?.books_per_day || 8;

      const today = new Date().toISOString().slice(0, 10);
      const generated = db
        .prepare(
          `SELECT COUNT(*) as cnt FROM books WHERE user_id = ? AND date = ?`
        )
        .get(user.id, today) as { cnt: number };
      const remainingToday = Math.max(0, booksPerDay - generated.cnt);

      insertPosition = remainingToday;
      // Shift topics at and after this position
      db.prepare(
        `UPDATE queue_topics SET position = position + 1 WHERE user_id = ? AND status = 'pending' AND position >= ?`
      ).run(user.id, insertPosition);
    } else {
      // End of Queue — append after the last pending topic
      const maxPos = (
        db
          .prepare(
            `SELECT MAX(position) as mp FROM queue_topics WHERE user_id = ? AND status = 'pending'`
          )
          .get(user.id) as { mp: number | null }
      ).mp;
      insertPosition = (maxPos ?? -1) + 1;
    }

    const id = uuidv4();
    const status = schedule === "Generate Now" ? "generating" : "pending";
    db.prepare(
      `INSERT INTO queue_topics (id, user_id, tier, title, description, position, status)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).run(id, user.id, tier || null, title, description || null, insertPosition, status);

    return id;
  });

  const id = insertTopic();

  const topic = db
    .prepare(`SELECT * FROM queue_topics WHERE id = ?`)
    .get(id);

  // Sync back to file
  writeBacklogToFile(user.id);

  // If "Generate Now", trigger generation via the built-in generator
  let jobId: string | undefined;
  if (schedule === "Generate Now") {
    const user = await getCurrentUser();
    if (user) {
      jobId = startGeneration(user.id, title, id);
    }
  }

  return NextResponse.json({ ...topic as object, jobId }, { status: 201 });
}
