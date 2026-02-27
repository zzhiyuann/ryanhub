import Database from "better-sqlite3";
import path from "path";
import fs from "fs";

const DATA_DIR = process.env.BOOKFACTORY_DATA_DIR || path.join(process.cwd(), "..", "data");
const DB_PATH = path.join(DATA_DIR, "bookfactory.db");

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

let _db: Database.Database | null = null;

export function getDb(): Database.Database {
  if (!_db) {
    _db = new Database(DB_PATH);
    _db.pragma("journal_mode = WAL");
    _db.pragma("foreign_keys = ON");
    initSchema(_db);
  }
  return _db;
}

function initSchema(db: Database.Database) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      display_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      openai_api_key TEXT,
      anthropic_api_key TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS books (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      title TEXT NOT NULL,
      topic TEXT,
      date TEXT NOT NULL,
      slot TEXT,
      word_count INTEGER DEFAULT 0,
      language TEXT DEFAULT 'zh',
      md_path TEXT,
      html_path TEXT,
      has_audio INTEGER DEFAULT 0,
      audio_duration REAL,
      audio_voice TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS audio_jobs (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL REFERENCES books(id),
      user_id TEXT NOT NULL REFERENCES users(id),
      status TEXT DEFAULT 'pending',
      progress REAL DEFAULT 0,
      chunks_total INTEGER DEFAULT 0,
      chunks_ready INTEGER DEFAULT 0,
      voice TEXT DEFAULT 'nova',
      error TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      completed_at DATETIME
    );

    CREATE TABLE IF NOT EXISTS queue_topics (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      tier TEXT,
      title TEXT NOT NULL,
      description TEXT,
      status TEXT DEFAULT 'pending',
      position INTEGER DEFAULT 0,
      generated_date TEXT,
      generated_slot TEXT,
      book_id TEXT REFERENCES books(id),
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS settings (
      user_id TEXT PRIMARY KEY REFERENCES users(id),
      books_per_day INTEGER DEFAULT 8,
      schedule TEXT DEFAULT '["00:00","06:00","12:00","18:00"]',
      tts_voice TEXT DEFAULT 'nova',
      tts_model TEXT DEFAULT 'tts-1-hd',
      book_source_dir TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_books_user ON books(user_id);
    CREATE INDEX IF NOT EXISTS idx_books_date ON books(date);
    CREATE INDEX IF NOT EXISTS idx_queue_user ON queue_topics(user_id, position);
    CREATE INDEX IF NOT EXISTS idx_audio_jobs_book ON audio_jobs(book_id);
  `);

  // Migrations: add columns if missing
  const audioJobsCols = db
    .prepare(`PRAGMA table_info(audio_jobs)`)
    .all() as { name: string }[];
  if (!audioJobsCols.some((c) => c.name === "mode")) {
    db.exec(`ALTER TABLE audio_jobs ADD COLUMN mode TEXT DEFAULT 'long'`);
  }
}
