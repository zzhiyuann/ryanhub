import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import { getBook, getBookContent } from "@/lib/books";
import { getDb } from "@/lib/db";
import {
  preprocessForAudio,
  summarizeForAudio,
  chunkText,
  generateChunkAudio,
  getAudioDir,
  getAudioChunkPath,
} from "@/lib/tts";
import { v4 as uuidv4 } from "uuid";
import fs from "fs";
import path from "path";

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  if (!user.openai_api_key) {
    return NextResponse.json(
      { error: "OpenAI API key not configured. Go to Settings to add it." },
      { status: 400 }
    );
  }

  const { bookId, voice, mode: requestedMode } = await req.json();
  const mode = requestedMode === "short" ? "short" : "long";
  const book = getBook(bookId);

  if (!book || book.user_id !== user.id) {
    return NextResponse.json({ error: "Book not found" }, { status: 404 });
  }

  // Short mode needs Anthropic key for summarization
  if (mode === "short" && !user.anthropic_api_key) {
    return NextResponse.json(
      { error: "Anthropic API key required for short audio. Add it in Settings." },
      { status: 400 }
    );
  }

  const db = getDb();

  // Check for already-in-progress job
  const existingJob = db
    .prepare(
      `SELECT id, status FROM audio_jobs WHERE book_id = ? AND user_id = ? AND status = 'processing' ORDER BY created_at DESC LIMIT 1`
    )
    .get(bookId, user.id) as { id: string; status: string } | undefined;

  if (existingJob) {
    return NextResponse.json(
      { error: "Audio generation already in progress for this book." },
      { status: 409 }
    );
  }

  const mdContent = getBookContent(bookId, "md");
  if (!mdContent) {
    return NextResponse.json(
      { error: "Book markdown content not found" },
      { status: 404 }
    );
  }

  const settings = db
    .prepare(`SELECT tts_voice, tts_model FROM settings WHERE user_id = ?`)
    .get(user.id) as { tts_voice: string; tts_model: string } | undefined;

  const ttsVoice = voice || settings?.tts_voice || "nova";
  const ttsModel = settings?.tts_model || "tts-1-hd";

  // Preprocess and chunk — short mode uses AI summary
  let processedText: string;
  let chapters: { title: string; charOffset: number }[];

  if (mode === "short") {
    const result = await summarizeForAudio(mdContent, user.anthropic_api_key!);
    processedText = result.text;
    chapters = result.chapters;
  } else {
    const result = preprocessForAudio(mdContent);
    processedText = result.text;
    chapters = result.chapters;
  }

  const chunks = chunkText(processedText);

  // Create audio job
  const jobId = uuidv4();
  db.prepare(
    `INSERT INTO audio_jobs (id, book_id, user_id, status, chunks_total, voice, created_at)
     VALUES (?, ?, ?, 'processing', ?, ?, CURRENT_TIMESTAMP)`
  ).run(jobId, bookId, user.id, chunks.length, ttsVoice);

  // Start async generation (don't await - runs in background)
  generateAudioAsync(
    jobId,
    bookId,
    book.title,
    chunks,
    chapters,
    user.openai_api_key,
    ttsVoice,
    ttsModel
  );

  return NextResponse.json({ jobId, status: "processing", chunksTotal: chunks.length });
}

function buildChapterMarkers(
  chapters: { title: string; charOffset: number }[],
  chunks: string[],
  chunkInfos: { index: number; duration: number; size: number; path: string }[]
) {
  let charAccumulated = 0;
  const chunkCharOffsets: number[] = [];
  for (const chunk of chunks) {
    chunkCharOffsets.push(charAccumulated);
    charAccumulated += chunk.length;
  }

  // Only build markers for chapters whose chunks are all generated
  const readyChunkCount = chunkInfos.length;

  return chapters
    .map((ch, idx) => {
      const startChunk = chunkCharOffsets.findIndex(
        (_, i) =>
          i === chunkCharOffsets.length - 1 ||
          chunkCharOffsets[i + 1] > ch.charOffset
      );
      if (startChunk >= readyChunkCount) return null;

      const nextChapter = chapters[idx + 1];
      let endChunk: number;
      if (nextChapter) {
        endChunk = chunkCharOffsets.findIndex(
          (_, i) =>
            i === chunkCharOffsets.length - 1 ||
            chunkCharOffsets[i + 1] > nextChapter.charOffset
        );
      } else {
        endChunk = readyChunkCount - 1;
      }
      endChunk = Math.min(endChunk, readyChunkCount - 1);

      let startTime = 0;
      for (let i = 0; i < startChunk; i++) startTime += chunkInfos[i].duration;

      let endTime = 0;
      for (let i = 0; i <= endChunk; i++) endTime += chunkInfos[i].duration;

      return {
        title: ch.title,
        startTime,
        endTime,
        startChunk: Math.max(0, startChunk),
        endChunk,
      };
    })
    .filter((m) => m !== null);
}

async function generateAudioAsync(
  jobId: string,
  bookId: string,
  bookTitle: string,
  chunks: string[],
  chapters: { title: string; charOffset: number }[],
  apiKey: string,
  voice: string,
  model: string
) {
  const db = getDb();
  const audioDir = getAudioDir(bookId);
  const manifestPath = path.join(audioDir, "manifest.json");

  let totalDuration = 0;
  const chunkInfos: { index: number; duration: number; size: number; path: string }[] = [];

  try {
    for (let i = 0; i < chunks.length; i++) {
      const audioBuffer = await generateChunkAudio(chunks[i], apiKey, voice, model);
      const chunkPath = getAudioChunkPath(bookId, i);
      fs.writeFileSync(chunkPath, audioBuffer);

      // Estimate duration from MP3 file size (128kbps = 16KB/s)
      const estimatedDuration = audioBuffer.length / 16000;
      totalDuration += estimatedDuration;

      chunkInfos.push({
        index: i,
        duration: estimatedDuration,
        size: audioBuffer.length,
        path: chunkPath,
      });

      // Write partial manifest after each chunk so streaming playback can start
      const partialManifest = {
        bookId,
        title: bookTitle,
        totalDuration,
        estimatedTotalDuration: totalDuration * (chunks.length / (i + 1)),
        voice,
        complete: false,
        chunksTotal: chunks.length,
        chunksReady: i + 1,
        chapters: buildChapterMarkers(chapters, chunks, chunkInfos),
        chunks: chunkInfos.map((c) => ({
          index: c.index,
          duration: c.duration,
          size: c.size,
          path: c.path,
        })),
      };
      fs.writeFileSync(manifestPath, JSON.stringify(partialManifest, null, 2));

      // Update progress in DB
      db.prepare(
        `UPDATE audio_jobs SET chunks_ready = ?, progress = ? WHERE id = ?`
      ).run(i + 1, (i + 1) / chunks.length, jobId);

      // Small delay to respect rate limits
      if (i < chunks.length - 1) {
        await new Promise((r) => setTimeout(r, 500));
      }
    }

    // Write final complete manifest
    const finalManifest = {
      bookId,
      title: bookTitle,
      totalDuration,
      voice,
      complete: true,
      chunksTotal: chunks.length,
      chunksReady: chunks.length,
      chapters: buildChapterMarkers(chapters, chunks, chunkInfos),
      chunks: chunkInfos.map((c) => ({
        index: c.index,
        duration: c.duration,
        size: c.size,
        path: c.path,
      })),
    };
    fs.writeFileSync(manifestPath, JSON.stringify(finalManifest, null, 2));

    // Update job and book
    db.prepare(
      `UPDATE audio_jobs SET status = 'done', progress = 1, completed_at = CURRENT_TIMESTAMP WHERE id = ?`
    ).run(jobId);

    db.prepare(
      `UPDATE books SET has_audio = 1, audio_duration = ?, audio_voice = ? WHERE id = ?`
    ).run(totalDuration, voice, bookId);
  } catch (error) {
    const errMsg = error instanceof Error ? error.message : String(error);
    db.prepare(
      `UPDATE audio_jobs SET status = 'error', error = ? WHERE id = ?`
    ).run(errMsg, jobId);
  }
}
