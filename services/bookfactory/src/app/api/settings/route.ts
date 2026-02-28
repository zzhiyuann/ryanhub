import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";
import { reschedule } from "@/lib/book-scheduler";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const db = getDb();
  const settings = db
    .prepare(`SELECT * FROM settings WHERE user_id = ?`)
    .get(user.id) as Record<string, unknown> | undefined;

  return NextResponse.json({
    settings: settings || {},
    api_keys: {
      has_openai_key: !!user.openai_api_key,
      has_anthropic_key: !!user.anthropic_api_key,
    },
  });
}

export async function PUT(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const body = await req.json();
  const db = getDb();

  // Update settings table
  const settingsFields = [
    "books_per_day",
    "schedule",
    "tts_voice",
    "tts_model",
    "book_source_dir",
  ];
  for (const field of settingsFields) {
    if (body[field] !== undefined) {
      const value =
        typeof body[field] === "object"
          ? JSON.stringify(body[field])
          : body[field];
      db.prepare(
        `UPDATE settings SET ${field} = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?`
      ).run(value, user.id);
    }
  }

  // Reschedule if books_per_day changed
  if (body.books_per_day !== undefined) {
    reschedule();
  }

  // Update API keys on users table
  if (body.openai_api_key !== undefined) {
    db.prepare(`UPDATE users SET openai_api_key = ? WHERE id = ?`).run(
      body.openai_api_key || null,
      user.id
    );
  }
  if (body.anthropic_api_key !== undefined) {
    db.prepare(`UPDATE users SET anthropic_api_key = ? WHERE id = ?`).run(
      body.anthropic_api_key || null,
      user.id
    );
  }

  return NextResponse.json({ ok: true });
}
