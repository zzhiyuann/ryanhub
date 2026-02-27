import { NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const db = getDb();
  const topics = db
    .prepare(
      `SELECT * FROM queue_topics WHERE user_id = ? ORDER BY position ASC`
    )
    .all(user.id);

  return NextResponse.json({ topics });
}
