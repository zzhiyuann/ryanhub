/**
 * Seed script: creates the zwang user and imports all existing books.
 * Run with: npx tsx scripts/seed.ts
 */

// Set working directory to server/ for db path resolution
process.chdir(__dirname + "/..");

import { getDb } from "../src/lib/db";
import { createUser } from "../src/lib/auth";
import { scanAndImportBooks } from "../src/lib/books";

const BOOK_SOURCE_DIR = "/Users/zwang/bookfactory";
const USERNAME = "zwang";
const PASSWORD = "bookfactory";
const DISPLAY_NAME = "Z. Wang";

async function seed() {
  const db = getDb();

  // Check if user already exists
  const existing = db
    .prepare(`SELECT id FROM users WHERE username = ?`)
    .get(USERNAME) as { id: string } | undefined;

  let userId: string;

  if (existing) {
    console.log(`User '${USERNAME}' already exists (id: ${existing.id})`);
    userId = existing.id;
  } else {
    const user = createUser(USERNAME, PASSWORD, DISPLAY_NAME);
    userId = user.id;
    console.log(`Created user '${USERNAME}' (id: ${userId})`);
  }

  // Set book source directory in settings
  db.prepare(
    `UPDATE settings SET book_source_dir = ? WHERE user_id = ?`
  ).run(BOOK_SOURCE_DIR, userId);

  // Scan and import books
  console.log(`\nScanning ${BOOK_SOURCE_DIR} for books...`);
  const result = scanAndImportBooks(userId, BOOK_SOURCE_DIR);
  console.log(`Scanned ${result.scanned} files, imported ${result.imported} new books.`);

  // Print summary
  const bookCount = (
    db.prepare(`SELECT COUNT(*) as c FROM books WHERE user_id = ?`).get(userId) as {
      c: number;
    }
  ).c;
  console.log(`\nTotal books in library: ${bookCount}`);

  // Print imported books
  const books = db
    .prepare(
      `SELECT title, date, word_count FROM books WHERE user_id = ? ORDER BY date DESC, created_at DESC`
    )
    .all(userId) as { title: string; date: string; word_count: number }[];

  console.log("\nBooks:");
  for (const book of books) {
    console.log(
      `  [${book.date}] ${book.title} (${book.word_count.toLocaleString()} words)`
    );
  }

  console.log(`\n✓ Done. Login with username='${USERNAME}', password='${PASSWORD}'`);
  console.log(`  (Change your password in production!)`);
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
