/**
 * Book Generator — spawns Claude CLI to generate books, then imports
 * the result directly into the database. No file watcher needed.
 *
 * Flow: receive request → spawn claude CLI → wait for completion →
 *       scan output dir → import to DB → update queue topic status
 */

import { spawn, type ChildProcess } from "child_process";
import fs from "fs";
import path from "path";
import { getDb } from "./db";
import { ingestBook } from "./books";

const BOOKFACTORY_DIR =
  process.env.BOOK_SOURCE_DIR || path.join(process.cwd(), "books");

interface GenerationJob {
  id: string;
  topic: string;
  userId: string;
  queueTopicId: string | null;
  slot: string;
  dateStr: string;
  status: "running" | "done" | "error";
  error?: string;
  bookId?: string;
  startedAt: number;
  process: ChildProcess | null;
  log: string;
}

const activeJobs = new Map<string, GenerationJob>();

/** Send a notification to RyanHub chat via Dispatcher WebSocket */
function sendRyanHubNotification(message: string): void {
  try {
    const WebSocket = require("ws");
    const ws = new WebSocket("ws://localhost:8765");
    ws.on("open", () => {
      ws.send(
        JSON.stringify({
          type: "notification",
          id: require("uuid").v4(),
          content: message,
          source: "Book Factory",
        })
      );
      // Close after a brief delay to ensure delivery
      setTimeout(() => ws.close(), 500);
    });
    ws.on("error", (err: Error) => {
      console.error(`[BookGenerator] RyanHub notification error:`, err.message);
    });
  } catch (e) {
    console.error(`[BookGenerator] RyanHub notification error:`, e);
  }
}

/** Load env vars from bookfactory/.env */
function loadEnv(): Record<string, string> {
  const envPath = path.join(BOOKFACTORY_DIR, ".env");
  const vars: Record<string, string> = {};
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, "utf-8");
    for (const line of content.split("\n")) {
      const match = line.match(/^([A-Z_]+)=(.+)$/);
      if (match) vars[match[1]] = match[2];
    }
  }
  return vars;
}

/** Build the prompt for Claude CLI (same structure as generate_now.sh) */
function buildPrompt(
  topic: string,
  slot: string,
  dateStr: string,
  envVars: Record<string, string>
): string {
  const telegramToken = envVars.TELEGRAM_BOT_TOKEN || "";
  const telegramChatId = envVars.TELEGRAM_CHAT_ID || "";

  return `You are generating a comprehensive book. Follow these steps precisely:

1. Read the file "CLAUDE_CODE_BRIEF.md" in the current working directory for full instructions on format, depth, quality, and LANGUAGE requirements (Chinese with English terms).
2. The topic is: ${topic}. Generate a comprehensive book on this topic.
3. Before writing, do extensive web research on the topic using WebSearch (at least 10-15 searches covering different angles: foundational theory, recent advances, applications, critiques, practitioner perspectives).
4. Generate the book following ALL specifications in the brief. Deep prose, not outlines.
5. Write the book to: ${dateStr}/${slot}_[topic_slug].md
6. Convert to HTML by running: python3 md_to_pdf.py "${dateStr}/${slot}_[topic_slug].md"
7. Send the HTML file via Telegram (only HTML, no PDF):
   curl -F chat_id="${telegramChatId}" -F document=@"path.html" -F caption="New book: [topic]" "https://api.telegram.org/bot${telegramToken}/sendDocument"

CRITICAL: Write in Chinese (zhong wen) with important English terms in parentheses. This is a personalized book for Zhiyuan Wang — 5th-year UVA PhD student transitioning to Meta Reality Labs Research Scientist (behavioral AI, multimodal sensing + social behavior). Write a REAL comprehensive book, not an outline.`;
}

/** Scan a date directory for new .html files not yet in DB */
function scanAndImportNewBooks(
  userId: string,
  dateStr: string,
  slot: string
): string | null {
  const dateDir = path.join(BOOKFACTORY_DIR, dateStr);
  if (!fs.existsSync(dateDir)) return null;

  const db = getDb();
  const files = fs.readdirSync(dateDir);
  // Look for html files matching this slot
  const htmlFiles = files.filter(
    (f) => f.endsWith(".html") && f.startsWith(slot)
  );

  for (const htmlFile of htmlFiles) {
    const htmlPath = path.join(dateDir, htmlFile);
    const baseName = path.basename(htmlFile, ".html");
    const mdPath = path.join(dateDir, baseName + ".md");
    const mdExists = fs.existsSync(mdPath);

    // Check if already in DB
    const existing = db
      .prepare(`SELECT id FROM books WHERE html_path = ?`)
      .get(htmlPath);
    if (existing) continue;

    // Import
    if (mdExists) {
      try {
        const book = ingestBook(userId, mdPath, htmlPath, dateStr);
        console.log(
          `[BookGenerator] Imported: "${book.title}" (${dateStr})`
        );
        return book.id;
      } catch (e) {
        console.error(`[BookGenerator] Failed to ingest ${mdPath}:`, e);
      }
    }
  }

  // Fallback: check ALL new html files in this date dir (slot name might vary)
  for (const htmlFile of files.filter((f) => f.endsWith(".html"))) {
    const htmlPath = path.join(dateDir, htmlFile);
    const existing = db
      .prepare(`SELECT id FROM books WHERE html_path = ?`)
      .get(htmlPath);
    if (existing) continue;

    const baseName = path.basename(htmlFile, ".html");
    const mdPath = path.join(dateDir, baseName + ".md");
    const mdExists = fs.existsSync(mdPath);

    if (mdExists) {
      try {
        const book = ingestBook(userId, mdPath, htmlPath, dateStr);
        console.log(
          `[BookGenerator] Imported (fallback scan): "${book.title}" (${dateStr})`
        );
        return book.id;
      } catch (e) {
        console.error(`[BookGenerator] Failed to ingest ${mdPath}:`, e);
      }
    }
  }

  return null;
}

/**
 * Generate a book by spawning Claude CLI.
 * Returns a job ID immediately. The generation runs in the background.
 */
export function startGeneration(
  userId: string,
  topic: string,
  queueTopicId: string | null = null
): string {
  const { v4: uuidv4 } = require("uuid");
  const jobId = uuidv4();
  const dateStr = new Date().toISOString().slice(0, 10);
  const hour = new Date().getHours().toString().padStart(2, "0");
  const min = new Date().getMinutes().toString().padStart(2, "0");
  const slot = `manual_${hour}${min}`;

  const envVars = loadEnv();
  const prompt = buildPrompt(topic, slot, dateStr, envVars);

  // Ensure output directory exists
  fs.mkdirSync(path.join(BOOKFACTORY_DIR, dateStr), { recursive: true });
  fs.mkdirSync(path.join(BOOKFACTORY_DIR, "logs"), { recursive: true });

  const logFile = path.join(
    BOOKFACTORY_DIR,
    "logs",
    `${dateStr}_server_${hour}${min}.log`
  );

  const job: GenerationJob = {
    id: jobId,
    topic,
    userId,
    queueTopicId,
    slot,
    dateStr,
    status: "running",
    startedAt: Date.now(),
    process: null,
    log: "",
  };

  // Spawn Claude CLI
  const env = {
    ...process.env,
    // Prevent nested Claude Code detection
    CLAUDECODE: undefined,
    CLAUDE_CODE: undefined,
    // Set max output tokens
    CLAUDE_CODE_MAX_OUTPUT_TOKENS:
      envVars.CLAUDE_CODE_MAX_OUTPUT_TOKENS || "128000",
    // Ensure PATH includes claude
    PATH: `${process.env.HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${process.env.PATH}`,
  };

  const child = spawn(
    "claude",
    ["--dangerously-skip-permissions", "-p", prompt, "--max-turns", "50"],
    {
      cwd: BOOKFACTORY_DIR,
      env: env as NodeJS.ProcessEnv,
      stdio: ["ignore", "pipe", "pipe"],
    }
  );

  job.process = child;
  activeJobs.set(jobId, job);

  // Log file stream
  const logStream = fs.createWriteStream(logFile, { flags: "a" });
  logStream.write(
    `[${new Date().toISOString()}] Generation started — topic: ${topic}\n`
  );

  child.stdout?.on("data", (data: Buffer) => {
    const text = data.toString();
    job.log += text;
    logStream.write(text);
  });

  child.stderr?.on("data", (data: Buffer) => {
    const text = data.toString();
    job.log += text;
    logStream.write(text);
  });

  child.on("close", (code: number | null) => {
    logStream.write(
      `\n[${new Date().toISOString()}] Process exited with code ${code}\n`
    );
    logStream.end();

    console.log(
      `[BookGenerator] Claude CLI exited (code ${code}) for topic: ${topic}`
    );

    // Scan for the generated book and import to DB
    const bookId = scanAndImportNewBooks(userId, dateStr, slot);

    const elapsed = Math.round((Date.now() - job.startedAt) / 60000);

    if (bookId) {
      job.status = "done";
      job.bookId = bookId;
      console.log(`[BookGenerator] Book imported: ${bookId}`);
      sendRyanHubNotification(
        `Book generated: "${topic}" (${elapsed} min)`
      );
    } else if (code === 0) {
      // CLI succeeded but we couldn't find the output — try broader scan
      console.warn(
        `[BookGenerator] CLI succeeded but no new book found for slot ${slot}`
      );
      job.status = "done";
      sendRyanHubNotification(
        `Book generation completed but not imported: "${topic}" (${elapsed} min)`
      );
    } else {
      job.status = "error";
      job.error = `Claude CLI exited with code ${code}`;
      console.error(`[BookGenerator] Generation failed: code ${code}`);
      sendRyanHubNotification(
        `Book generation failed: "${topic}" (exit code ${code}, ${elapsed} min)`
      );
    }

    // Update queue topic status
    if (queueTopicId) {
      const db = getDb();
      const newStatus = job.status === "error" ? "pending" : "done";
      db.prepare(
        `UPDATE queue_topics SET status = ?, generated_date = ?, generated_slot = ? WHERE id = ?`
      ).run(newStatus, dateStr, slot, queueTopicId);
    }

    // Clean up process reference
    job.process = null;

    // Keep job in memory for status checks (clean up after 1 hour)
    setTimeout(() => activeJobs.delete(jobId), 60 * 60 * 1000);
  });

  console.log(
    `[BookGenerator] Started job ${jobId} — topic: "${topic}", slot: ${slot}`
  );
  return jobId;
}

/** Get status of a generation job */
export function getJobStatus(jobId: string): Omit<GenerationJob, "process"> | null {
  const job = activeJobs.get(jobId);
  if (!job) return null;
  // Don't expose the process object
  const { process: _, ...rest } = job;
  return rest;
}

/** List all active/recent jobs */
export function listJobs(): Array<{
  id: string;
  topic: string;
  status: string;
  startedAt: number;
  bookId?: string;
}> {
  return Array.from(activeJobs.values()).map((j) => ({
    id: j.id,
    topic: j.topic,
    status: j.status,
    startedAt: j.startedAt,
    bookId: j.bookId,
  }));
}

/** Cancel a running generation */
export function cancelGeneration(jobId: string): boolean {
  const job = activeJobs.get(jobId);
  if (!job || !job.process) return false;
  job.process.kill("SIGTERM");
  job.status = "error";
  job.error = "Cancelled by user";
  return true;
}
