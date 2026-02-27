import { getDb } from "./db";
import { v4 as uuidv4 } from "uuid";
import fs from "fs";
import path from "path";

export interface Book {
  id: string;
  user_id: string;
  title: string;
  topic: string | null;
  date: string;
  slot: string | null;
  word_count: number;
  language: string;
  md_path: string | null;
  html_path: string | null;
  has_audio: number;
  audio_duration: number | null;
  audio_voice: string | null;
  created_at: string;
}

export function listBooks(
  userId: string,
  opts?: { since?: string; limit?: number }
): Book[] {
  const db = getDb();
  let query = `SELECT * FROM books WHERE user_id = ?`;
  const params: (string | number)[] = [userId];

  if (opts?.since) {
    query += ` AND created_at > ?`;
    params.push(opts.since);
  }

  query += ` ORDER BY date DESC, created_at DESC`;

  if (opts?.limit) {
    query += ` LIMIT ?`;
    params.push(opts.limit);
  }

  return db.prepare(query).all(...params) as Book[];
}

export function getBook(bookId: string): Book | null {
  const db = getDb();
  return (db.prepare(`SELECT * FROM books WHERE id = ?`).get(bookId) as Book) || null;
}

export function getBookContent(
  bookId: string,
  format: "html" | "md" = "html"
): string | null {
  const book = getBook(bookId);
  if (!book) return null;

  const filePath = format === "html" ? book.html_path : book.md_path;
  if (!filePath || !fs.existsSync(filePath)) return null;

  return fs.readFileSync(filePath, "utf-8");
}

function countWords(text: string): number {
  // Handle CJK characters (each counts as ~1 word) + English words
  const cjk = text.match(/[\u4e00-\u9fff\u3400-\u4dbf]/g)?.length || 0;
  const english = text
    .replace(/[\u4e00-\u9fff\u3400-\u4dbf]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 0).length;
  return cjk + english;
}

function extractTitle(mdContent: string): string {
  // Try to find the first H1
  const h1Match = mdContent.match(/^#\s+(.+)$/m);
  if (h1Match) return h1Match[1].trim();
  // Fallback: first non-empty line
  const firstLine = mdContent.split("\n").find((l) => l.trim().length > 0);
  return firstLine?.replace(/^#+\s*/, "").trim() || "Untitled";
}

function extractTopic(mdContent: string): string | null {
  const topicMatch = mdContent.match(/\*\*Topic:\*\*\s*(.+)/);
  return topicMatch ? topicMatch[1].trim() : null;
}

function extractSlot(mdContent: string): string | null {
  const slotMatch = mdContent.match(/\*\*Slot:\*\*\s*(.+)/);
  return slotMatch ? slotMatch[1].trim() : null;
}

export function ingestBook(
  userId: string,
  mdPath: string,
  htmlPath: string | null,
  dateStr: string
): Book {
  const db = getDb();
  const id = uuidv4();

  const mdContent = fs.readFileSync(mdPath, "utf-8");
  const title = extractTitle(mdContent);
  const topic = extractTopic(mdContent);
  const slot = extractSlot(mdContent);
  const wordCount = countWords(mdContent);

  db.prepare(
    `INSERT INTO books (id, user_id, title, topic, date, slot, word_count, md_path, html_path)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(id, userId, title, topic, dateStr, slot, wordCount, mdPath, htmlPath);

  return db.prepare(`SELECT * FROM books WHERE id = ?`).get(id) as Book;
}

/**
 * Scan a directory for existing books and import them.
 * Looks for date-based subdirectories (YYYY-MM-DD) containing .md files.
 */
export function scanAndImportBooks(
  userId: string,
  sourceDir: string
): { scanned: number; imported: number } {
  const db = getDb();
  let scanned = 0;
  let imported = 0;

  // Get all existing md_paths for this user to avoid duplicates
  const existingPaths = new Set(
    (
      db
        .prepare(`SELECT md_path FROM books WHERE user_id = ?`)
        .all(userId) as { md_path: string }[]
    ).map((r) => r.md_path)
  );

  // Also scan root-level MD files (early books not in date directories)
  const entries = fs.readdirSync(sourceDir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(sourceDir, entry.name);

    if (entry.isDirectory() && /^\d{4}-\d{2}-\d{2}$/.test(entry.name)) {
      // Date-based directory
      const dateStr = entry.name;
      const files = fs.readdirSync(fullPath);
      const mdFiles = files.filter((f) => f.endsWith(".md"));

      for (const mdFile of mdFiles) {
        scanned++;
        const mdPath = path.join(fullPath, mdFile);

        if (existingPaths.has(mdPath)) continue;

        const htmlFile = mdFile.replace(/\.md$/, ".html");
        const htmlPath = files.includes(htmlFile)
          ? path.join(fullPath, htmlFile)
          : null;

        try {
          ingestBook(userId, mdPath, htmlPath, dateStr);
          imported++;
        } catch (e) {
          console.error(`Failed to ingest ${mdPath}:`, e);
        }
      }
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      // Root-level MD files (not config/backlog files)
      if (
        entry.name === "topic_backlog.md" ||
        entry.name === "CLAUDE_CODE_BRIEF.md"
      )
        continue;

      scanned++;
      const mdPath = fullPath;

      if (existingPaths.has(mdPath)) continue;

      const htmlFile = entry.name.replace(/\.md$/, ".html");
      const htmlPath = entries.find((e) => e.name === htmlFile)
        ? path.join(sourceDir, htmlFile)
        : null;

      // Try to extract date from content, fallback to file mtime
      const content = fs.readFileSync(mdPath, "utf-8");
      const dateMatch = content.match(
        /\*\*(?:Date|日期)[：:]\*\*\s*(\d{4}-\d{2}-\d{2})/
      );
      const dateStr = dateMatch
        ? dateMatch[1]
        : new Date(fs.statSync(mdPath).mtime).toISOString().slice(0, 10);

      try {
        ingestBook(userId, mdPath, htmlPath, dateStr);
        imported++;
      } catch (e) {
        console.error(`Failed to ingest ${mdPath}:`, e);
      }
    }
  }

  return { scanned, imported };
}
