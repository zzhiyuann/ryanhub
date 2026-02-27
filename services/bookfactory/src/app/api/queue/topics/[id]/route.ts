import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";
import { writeBacklogToFile } from "@/lib/backlog-sync";

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { id } = await params;
  const body = await req.json();
  const db = getDb();

  // Verify ownership
  const topic = db
    .prepare(`SELECT * FROM queue_topics WHERE id = ? AND user_id = ?`)
    .get(id, user.id);
  if (!topic) {
    return NextResponse.json({ error: "Topic not found" }, { status: 404 });
  }

  const updates: string[] = [];
  const values: unknown[] = [];

  if (body.title !== undefined) {
    updates.push("title = ?");
    values.push(body.title);
  }
  if (body.status !== undefined) {
    updates.push("status = ?");
    values.push(body.status);
  }
  if (body.tier !== undefined) {
    updates.push("tier = ?");
    values.push(body.tier);
  }
  if (body.description !== undefined) {
    updates.push("description = ?");
    values.push(body.description);
  }

  if (updates.length > 0) {
    values.push(id);
    db.prepare(
      `UPDATE queue_topics SET ${updates.join(", ")} WHERE id = ?`
    ).run(...values);
  }

  const updated = db.prepare(`SELECT * FROM queue_topics WHERE id = ?`).get(id);

  // Sync back to file
  writeBacklogToFile(user.id);

  return NextResponse.json(updated);
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { id } = await params;
  const db = getDb();

  // Get position before deleting so we can re-compact
  const topic = db
    .prepare(`SELECT position, status FROM queue_topics WHERE id = ? AND user_id = ?`)
    .get(id, user.id) as { position: number; status: string } | undefined;

  if (!topic) {
    return NextResponse.json({ error: "Topic not found" }, { status: 404 });
  }

  db.transaction(() => {
    db.prepare(`DELETE FROM queue_topics WHERE id = ?`).run(id);
    // Re-compact positions to avoid gaps
    if (topic.status === "pending") {
      db.prepare(
        `UPDATE queue_topics SET position = position - 1 WHERE user_id = ? AND status = 'pending' AND position > ?`
      ).run(user.id, topic.position);
    }
  })();

  // Sync back to file
  writeBacklogToFile(user.id);

  return new NextResponse(null, { status: 204 });
}
