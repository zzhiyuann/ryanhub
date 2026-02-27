import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getBook } from "@/lib/books";
import { getAudioManifest } from "@/lib/tts";

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ bookId: string }> }
) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { bookId } = await params;
  const book = getBook(bookId);

  if (!book || book.user_id !== user.id) {
    return NextResponse.json({ error: "Book not found" }, { status: 404 });
  }

  const manifest = getAudioManifest(bookId);
  if (!manifest) {
    return NextResponse.json(
      { error: "No audio available for this book" },
      { status: 404 }
    );
  }

  return NextResponse.json(manifest);
}
