import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getDb } from "@/lib/db";
import { writeBacklogToFile } from "@/lib/backlog-sync";

export async function PUT(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { topicIds } = await req.json();

  if (!Array.isArray(topicIds)) {
    return NextResponse.json(
      { error: "topicIds must be an array" },
      { status: 400 }
    );
  }

  const db = getDb();
  const update = db.prepare(
    `UPDATE queue_topics SET position = ? WHERE id = ? AND user_id = ?`
  );

  const transaction = db.transaction(() => {
    for (let i = 0; i < topicIds.length; i++) {
      update.run(i, topicIds[i], user.id);
    }
  });

  transaction();

  // Sync back to file
  writeBacklogToFile(user.id);

  return NextResponse.json({ ok: true });
}
