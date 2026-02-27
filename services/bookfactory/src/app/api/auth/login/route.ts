import { NextRequest, NextResponse } from "next/server";
import { verifyLogin, generateToken } from "@/lib/auth";

export async function POST(req: NextRequest) {
  const { username, password } = await req.json();

  if (!username || !password) {
    return NextResponse.json(
      { error: "Username and password required" },
      { status: 400 }
    );
  }

  const user = verifyLogin(username, password);
  if (!user) {
    return NextResponse.json(
      { error: "Invalid credentials" },
      { status: 401 }
    );
  }

  const token = generateToken(user);
  const res = NextResponse.json({
    token,
    user: {
      id: user.id,
      username: user.username,
      display_name: user.display_name,
    },
  });

  res.cookies.set("bf_session", token, {
    httpOnly: true,
    sameSite: "lax",
    maxAge: 30 * 24 * 60 * 60, // 30 days
    path: "/",
  });

  return res;
}
