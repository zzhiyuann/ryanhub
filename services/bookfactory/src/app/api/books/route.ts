import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { listBooks } from "@/lib/books";

export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  console.log("[books/route] getCurrentUser returned:", user ? user.username : null);
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const since = req.nextUrl.searchParams.get("since") || undefined;
  const limit = req.nextUrl.searchParams.get("limit");

  const books = listBooks(user.id, {
    since,
    limit: limit ? parseInt(limit, 10) : undefined,
  });

  return NextResponse.json({ books });
}
