import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getBook } from "@/lib/books";
import { getAudioChunkPath } from "@/lib/tts";
import fs from "fs";

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ bookId: string; n: string }> }
) {
  // Support auth via cookie, Authorization header, or query param (for AVPlayer)
  let user = await getCurrentUser();
  if (!user) {
    const tokenParam = req.nextUrl.searchParams.get("token");
    if (tokenParam) {
      const { verifyToken, getUserById } = await import("@/lib/auth");
      const payload = verifyToken(tokenParam);
      if (payload) user = getUserById(payload.userId);
    }
  }
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { bookId, n } = await params;
  const book = getBook(bookId);

  if (!book || book.user_id !== user.id) {
    return NextResponse.json({ error: "Book not found" }, { status: 404 });
  }

  const chunkPath = getAudioChunkPath(bookId, parseInt(n, 10));

  if (!fs.existsSync(chunkPath)) {
    return NextResponse.json(
      { error: "Audio chunk not found" },
      { status: 404 }
    );
  }

  const buffer = fs.readFileSync(chunkPath);
  const rangeHeader = req.headers.get("range");

  if (rangeHeader) {
    const [startStr, endStr] = rangeHeader.replace("bytes=", "").split("-");
    const start = parseInt(startStr, 10);
    const end = endStr ? parseInt(endStr, 10) : buffer.length - 1;
    const chunk = buffer.subarray(start, end + 1);

    return new NextResponse(chunk, {
      status: 206,
      headers: {
        "Content-Type": "audio/mpeg",
        "Content-Range": `bytes ${start}-${end}/${buffer.length}`,
        "Content-Length": String(chunk.length),
        "Accept-Ranges": "bytes",
      },
    });
  }

  return new NextResponse(buffer, {
    headers: {
      "Content-Type": "audio/mpeg",
      "Content-Length": String(buffer.length),
      "Accept-Ranges": "bytes",
      "Cache-Control": "public, max-age=31536000",
    },
  });
}
