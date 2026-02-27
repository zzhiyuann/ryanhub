import { NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  return NextResponse.json({
    user: {
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      has_openai_key: !!user.openai_api_key,
      has_anthropic_key: !!user.anthropic_api_key,
    },
  });
}
