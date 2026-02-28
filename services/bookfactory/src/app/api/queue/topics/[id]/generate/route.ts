import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";
import { startGeneration } from "@/lib/book-generator";
import { writeBacklogToFile } from "@/lib/backlog-sync";

/** POST /api/queue/topics/[id]/generate — Generate a topic immediately.
 *
 * Moves the topic to position 0 (top of queue), shifts others down,
 * sets status to "generating", and triggers generation.
 */
export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { id } = await params;
  const db = getDb();

  const topic = db
    .prepare(`SELECT * FROM queue_topics WHERE id = ? AND user_id = ?`)
    .get(id, user.id) as { id: string; title: string; status: string; position: number } | undefined;

  if (!topic) {
    return NextResponse.json({ error: "Topic not found" }, { status: 404 });
  }

  if (topic.status !== "pending") {
    return NextResponse.json(
      { error: `Cannot generate topic with status "${topic.status}"` },
      { status: 400 }
    );
  }

  // Move to position 0 and shift others down, all in a transaction
  db.transaction(() => {
    // First, shift down all pending topics that were above this one
    db.prepare(
      `UPDATE queue_topics SET position = position - 1
       WHERE user_id = ? AND status = 'pending' AND position > ?`
    ).run(user.id, topic.position);

    // Shift all pending topics down by 1 to make room at position 0
    db.prepare(
      `UPDATE queue_topics SET position = position + 1
       WHERE user_id = ? AND status = 'pending' AND id != ?`
    ).run(user.id, id);

    // Place this topic at position 0 and mark as generating
    db.prepare(
      `UPDATE queue_topics SET position = 0, status = 'generating' WHERE id = ?`
    ).run(id);
  })();

  // Sync backlog file
  writeBacklogToFile(user.id);

  // Trigger generation
  const jobId = startGeneration(user.id, topic.title, id);

  return NextResponse.json({ ok: true, jobId });
}
