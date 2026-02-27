import { getDb } from "./db";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { v4 as uuidv4 } from "uuid";
import { cookies } from "next/headers";

const JWT_SECRET = process.env.JWT_SECRET || "bookfactory-secret-change-me";
const COOKIE_NAME = "bf_session";

export interface User {
  id: string;
  username: string;
  display_name: string;
  openai_api_key: string | null;
  anthropic_api_key: string | null;
  created_at: string;
}

export function createUser(
  username: string,
  password: string,
  displayName: string
): User {
  const db = getDb();
  const id = uuidv4();
  const passwordHash = bcrypt.hashSync(password, 10);

  db.prepare(
    `INSERT INTO users (id, username, display_name, password_hash) VALUES (?, ?, ?, ?)`
  ).run(id, username, displayName, passwordHash);

  db.prepare(`INSERT INTO settings (user_id) VALUES (?)`).run(id);

  return {
    id,
    username,
    display_name: displayName,
    openai_api_key: null,
    anthropic_api_key: null,
    created_at: new Date().toISOString(),
  };
}

export function verifyLogin(
  username: string,
  password: string
): User | null {
  const db = getDb();
  const row = db
    .prepare(`SELECT * FROM users WHERE username = ?`)
    .get(username) as {
    id: string;
    username: string;
    display_name: string;
    password_hash: string;
    openai_api_key: string | null;
    anthropic_api_key: string | null;
    created_at: string;
  } | undefined;

  if (!row) return null;
  if (!bcrypt.compareSync(password, row.password_hash)) return null;

  return {
    id: row.id,
    username: row.username,
    display_name: row.display_name,
    openai_api_key: row.openai_api_key,
    anthropic_api_key: row.anthropic_api_key,
    created_at: row.created_at,
  };
}

export function generateToken(user: User): string {
  return jwt.sign({ userId: user.id, username: user.username }, JWT_SECRET, {
    expiresIn: "30d",
  });
}

export function verifyToken(token: string): { userId: string; username: string } | null {
  try {
    return jwt.verify(token, JWT_SECRET) as { userId: string; username: string };
  } catch {
    return null;
  }
}

export async function getCurrentUser(): Promise<User | null> {
  const db = getDb();
  let token: string | undefined;

  try {
    // Check cookie first, then fall back to Authorization header (for mobile clients)
    const cookieStore = await cookies();
    token = cookieStore.get(COOKIE_NAME)?.value;

    if (!token) {
      const { headers } = await import("next/headers");
      const headerStore = await headers();
      const authHeader = headerStore.get("authorization");
      if (authHeader?.startsWith("Bearer ")) {
        token = authHeader.slice(7);
      }
    }
  } catch {
    // cookies/headers may throw outside request context
  }

  if (token) {
    const payload = verifyToken(token);
    if (payload) {
      const row = db
        .prepare(
          `SELECT id, username, display_name, openai_api_key, anthropic_api_key, created_at FROM users WHERE id = ?`
        )
        .get(payload.userId) as User | undefined;
      if (row) return row;
    }
  }

  // No valid token — fall back to the first user (single-user personal app)
  const fallback = db
    .prepare(
      `SELECT id, username, display_name, openai_api_key, anthropic_api_key, created_at FROM users ORDER BY created_at ASC LIMIT 1`
    )
    .get() as User | undefined;

  return fallback || null;
}

export function getUserById(userId: string): User | null {
  const db = getDb();
  const row = db
    .prepare(
      `SELECT id, username, display_name, openai_api_key, anthropic_api_key, created_at FROM users WHERE id = ?`
    )
    .get(userId) as User | undefined;
  return row || null;
}
