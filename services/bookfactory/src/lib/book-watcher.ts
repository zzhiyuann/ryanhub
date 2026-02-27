/**
 * Book Watcher — automatically imports new books into the database
 * when .html files appear in the bookfactory date directories.
 *
 * Trigger: new .html file in a YYYY-MM-DD subdirectory
 * Action: find matching .md, extract metadata, insert into DB
 * Dedup: skip if md_path or html_path already in DB
 */

import chokidar from "chokidar";
import fs from "fs";
import path from "path";
import { getDb } from "./db";
import { ingestBook } from "./books";

let watcher: ReturnType<typeof chokidar.watch> | null = null;

/**
 * Resolve the user who owns a given source directory.
 * Checks settings.book_source_dir for a match.
 * Falls back to the first user if no match.
 */
function resolveUserId(sourceDir: string): string | null {
  const db = getDb();

  // Check if any user has this as their book_source_dir
  const setting = db
    .prepare(`SELECT user_id FROM settings WHERE book_source_dir = ?`)
    .get(sourceDir) as { user_id: string } | undefined;
  if (setting) return setting.user_id;

  // Fallback: first user
  const user = db.prepare(`SELECT id FROM users LIMIT 1`).get() as
    | { id: string }
    | undefined;
  return user?.id || null;
}

/**
 * Check if a book with this html_path or md_path already exists.
 */
function isAlreadyImported(htmlPath: string, mdPath: string | null): boolean {
  const db = getDb();
  const byHtml = db
    .prepare(`SELECT id FROM books WHERE html_path = ?`)
    .get(htmlPath);
  if (byHtml) return true;

  if (mdPath) {
    const byMd = db
      .prepare(`SELECT id FROM books WHERE md_path = ?`)
      .get(mdPath);
    if (byMd) return true;
  }

  return false;
}

/**
 * Import a single HTML book file into the database.
 */
function importBook(htmlPath: string): void {
  // Extract date from parent directory name (YYYY-MM-DD)
  const dir = path.dirname(htmlPath);
  const dirName = path.basename(dir);
  const dateMatch = dirName.match(/^(\d{4}-\d{2}-\d{2})$/);
  if (!dateMatch) {
    console.log(`[BookWatcher] Skipping ${htmlPath} — parent dir is not a date`);
    return;
  }
  const dateStr = dateMatch[1];

  // Find matching .md file
  const baseName = path.basename(htmlPath, ".html");
  const mdPath = path.join(dir, baseName + ".md");
  const mdExists = fs.existsSync(mdPath);

  // Dedup check
  if (isAlreadyImported(htmlPath, mdExists ? mdPath : null)) {
    return; // Already in DB, skip silently
  }

  // Resolve which user owns this directory
  const sourceDir = path.dirname(dir); // parent of date dir
  const userId = resolveUserId(sourceDir);
  if (!userId) {
    console.error(`[BookWatcher] No user found for ${sourceDir}`);
    return;
  }

  // Import
  if (mdExists) {
    // Use ingestBook which reads MD for metadata
    try {
      const book = ingestBook(userId, mdPath, htmlPath, dateStr);
      console.log(`[BookWatcher] Imported: "${book.title}" (${dateStr})`);
    } catch (e) {
      console.error(`[BookWatcher] Failed to ingest ${mdPath}:`, e);
    }
  } else {
    // No .md — import with just HTML, extract title from filename
    const db = getDb();
    const { v4: uuidv4 } = require("uuid");
    const id = uuidv4();
    const title = baseName
      .replace(/^(slot\d+|auto|manual)_\d+_/, "")
      .replace(/_/g, " ")
      .replace(/\b\w/g, (c: string) => c.toUpperCase());

    db.prepare(
      `INSERT INTO books (id, user_id, title, date, html_path, md_path)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).run(id, userId, title, dateStr, htmlPath, null);

    console.log(`[BookWatcher] Imported (HTML only): "${title}" (${dateStr})`);
  }
}

/**
 * Startup scan: import any books on disk that are missing from the DB,
 * and fix any existing books that have md_path but no html_path.
 */
export function scanMissingBooks(sourceDir: string): {
  scanned: number;
  imported: number;
  repaired: number;
} {
  let scanned = 0;
  let imported = 0;
  let repaired = 0;

  if (!fs.existsSync(sourceDir)) return { scanned, imported, repaired };

  const db = getDb();
  const entries = fs.readdirSync(sourceDir, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isDirectory() || !/^\d{4}-\d{2}-\d{2}$/.test(entry.name))
      continue;

    const dateDir = path.join(sourceDir, entry.name);
    const files = fs.readdirSync(dateDir);
    const htmlFiles = files.filter((f) => f.endsWith(".html"));

    for (const htmlFile of htmlFiles) {
      scanned++;
      const htmlPath = path.join(dateDir, htmlFile);
      const baseName = path.basename(htmlFile, ".html");
      const mdPath = path.join(dateDir, baseName + ".md");
      const mdExists = fs.existsSync(mdPath);

      // Case 1: book exists in DB by md_path but html_path is missing — repair it
      if (mdExists) {
        const existing = db
          .prepare(
            `SELECT id, html_path FROM books WHERE md_path = ? AND (html_path IS NULL OR html_path = '')`
          )
          .get(mdPath) as { id: string; html_path: string | null } | undefined;
        if (existing) {
          db.prepare(`UPDATE books SET html_path = ? WHERE id = ?`).run(
            htmlPath,
            existing.id
          );
          repaired++;
          continue;
        }
      }

      // Case 2: not in DB at all — import
      if (!isAlreadyImported(htmlPath, mdExists ? mdPath : null)) {
        importBook(htmlPath);
        imported++;
      }
    }
  }

  return { scanned, imported, repaired };
}

/**
 * Start watching the source directory for new .html files.
 * Call this once at server startup.
 */
export function startBookWatcher(sourceDir: string): void {
  if (watcher) {
    console.log("[BookWatcher] Already running");
    return;
  }

  // First: scan for any missing books (catch up after downtime)
  const result = scanMissingBooks(sourceDir);
  if (result.imported > 0 || result.repaired > 0) {
    console.log(
      `[BookWatcher] Startup scan: ${result.imported} imported, ${result.repaired} repaired (${result.scanned} scanned)`
    );
  }

  // Watch the source directory for new .html files in date subdirectories.
  // NOTE: chokidar v5 does not reliably expand glob patterns for directories
  // that don't yet exist or are empty at watch time. Instead, we watch the
  // whole sourceDir (depth-limited) and filter in the event handler.
  watcher = chokidar.watch(sourceDir, {
    ignoreInitial: true, // Don't fire for existing files
    depth: 1, // sourceDir -> date-dir -> files (2 levels = depth 1)
    awaitWriteFinish: {
      stabilityThreshold: 3000, // Wait 3s after last write before firing
      pollInterval: 500,
    },
  });

  watcher.on("add", (filePath: string) => {
    // Only process .html files inside YYYY-MM-DD subdirectories
    if (!filePath.endsWith(".html")) return;
    const dirName = path.basename(path.dirname(filePath));
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dirName)) return;

    console.log(`[BookWatcher] New file detected: ${filePath}`);
    // Small extra delay to ensure file is fully written
    setTimeout(() => {
      try {
        importBook(filePath);
      } catch (e) {
        console.error(`[BookWatcher] Error importing ${filePath}:`, e);
      }
    }, 2000);
  });

  watcher.on("error", (error: unknown) => {
    console.error("[BookWatcher] Watcher error:", error);
  });

  console.log(`[BookWatcher] Watching ${sourceDir} for new books`);
}

/**
 * Stop the watcher (for graceful shutdown).
 */
export function stopBookWatcher(): void {
  if (watcher) {
    watcher.close();
    watcher = null;
    console.log("[BookWatcher] Stopped");
  }
}
