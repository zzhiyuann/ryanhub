import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ bookId: string }> }
) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { bookId } = await params;
  const db = getDb();

  const job = db
    .prepare(
      `SELECT * FROM audio_jobs WHERE book_id = ? AND user_id = ? ORDER BY created_at DESC LIMIT 1`
    )
    .get(bookId, user.id) as Record<string, unknown> | undefined;

  if (!job) {
    return NextResponse.json({ status: "none" });
  }

  return NextResponse.json({
    jobId: job.id,
    status: job.status,
    progress: job.progress,
    chunksReady: job.chunks_ready,
    chunksTotal: job.chunks_total,
    error: job.error,
  });
}
