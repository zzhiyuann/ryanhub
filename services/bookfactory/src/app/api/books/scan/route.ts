import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { scanAndImportBooks } from "@/lib/books";
import { getDb } from "@/lib/db";

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { source_dir } = await req.json().catch(() => ({ source_dir: null }));

  // Use provided dir or fall back to user's configured dir or default
  const db = getDb();
  const settings = db
    .prepare(`SELECT book_source_dir FROM settings WHERE user_id = ?`)
    .get(user.id) as { book_source_dir: string | null } | undefined;

  const dir =
    source_dir || settings?.book_source_dir || "/Users/zwang/bookfactory";

  const result = scanAndImportBooks(user.id, dir);

  return NextResponse.json(result);
}
