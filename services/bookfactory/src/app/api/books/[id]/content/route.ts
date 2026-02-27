import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getBook, getBookContent } from "@/lib/books";

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { id } = await params;
  const book = getBook(id);

  if (!book || book.user_id !== user.id) {
    return NextResponse.json({ error: "Book not found" }, { status: 404 });
  }

  const format = (req.nextUrl.searchParams.get("format") || "html") as
    | "html"
    | "md";
  const content = getBookContent(id, format);

  if (!content) {
    return NextResponse.json(
      { error: "Content file not found" },
      { status: 404 }
    );
  }

  if (format === "html") {
    return new NextResponse(content, {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  return new NextResponse(content, {
    headers: { "Content-Type": "text/markdown; charset=utf-8" },
  });
}
