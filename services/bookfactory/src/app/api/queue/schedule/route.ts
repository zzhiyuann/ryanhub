import { NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const db = getDb();

  const settings = db
    .prepare(`SELECT books_per_day FROM settings WHERE user_id = ?`)
    .get(user.id) as { books_per_day: number } | undefined;
  const booksPerDay = settings?.books_per_day || 8;

  // Count books already generated today
  const today = new Date().toISOString().slice(0, 10);
  const generated = db
    .prepare(
      `SELECT COUNT(*) as cnt FROM books WHERE user_id = ? AND date = ?`
    )
    .get(user.id, today) as { cnt: number };
  const generatedToday = generated.cnt;

  // Get pending topics in queue order
  const pending = db
    .prepare(
      `SELECT * FROM queue_topics WHERE user_id = ? AND status = 'pending' ORDER BY position ASC`
    )
    .all(user.id);

  const remainingToday = Math.max(0, booksPerDay - generatedToday);
  const todayTopics = pending.slice(0, remainingToday);
  const tomorrowTopics = pending.slice(
    remainingToday,
    remainingToday + booksPerDay
  );

  return NextResponse.json({
    today: todayTopics,
    tomorrow: tomorrowTopics,
    booksPerDay,
    generatedToday,
    remainingToday,
  });
}
