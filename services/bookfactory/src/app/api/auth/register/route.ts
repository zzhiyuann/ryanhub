import { NextRequest, NextResponse } from "next/server";
import { createUser, generateToken } from "@/lib/auth";
import { getDb } from "@/lib/db";

export async function POST(req: NextRequest) {
  const { username, password, display_name } = await req.json();

  if (!username || !password) {
    return NextResponse.json(
      { error: "Username and password required" },
      { status: 400 }
    );
  }

  // Check if username exists
  const db = getDb();
  const existing = db
    .prepare(`SELECT id FROM users WHERE username = ?`)
    .get(username);
  if (existing) {
    return NextResponse.json(
      { error: "Username already taken" },
      { status: 409 }
    );
  }

  const user = createUser(username, password, display_name || username);
  const token = generateToken(user);

  const res = NextResponse.json({
    user: {
      id: user.id,
      username: user.username,
      display_name: user.display_name,
    },
  });

  res.cookies.set("bf_session", token, {
    httpOnly: true,
    sameSite: "lax",
    maxAge: 30 * 24 * 60 * 60,
    path: "/",
  });

  return res;
}
