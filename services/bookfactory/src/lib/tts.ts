import fs from "fs";
import path from "path";

const DATA_DIR = process.env.BOOKFACTORY_DATA_DIR || path.join(process.cwd(), "..", "data");
const AUDIO_DIR = path.join(DATA_DIR, "audio");

export interface AudioManifest {
  bookId: string;
  title: string;
  totalDuration: number;
  voice: string;
  chapters: ChapterMarker[];
  chunks: AudioChunkInfo[];
}

export interface ChapterMarker {
  title: string;
  startTime: number;
  endTime: number;
  startChunk: number;
  endChunk: number;
}

export interface AudioChunkInfo {
  index: number;
  duration: number;
  size: number;
  path: string;
}

// Patterns for sections to skip in audio generation (references, glossaries, etc.)
const SKIP_SECTION_PATTERNS = [
  /^references?\s*$/i,
  /^bibliography\s*$/i,
  /^glossary/i,
  /^recommended\s+reading/i,
  /^further\s+reading/i,
  /^suggested\s+reading/i,
  /^additional\s+reading/i,
  /^appendix/i,
  /^appendices/i,
  /^works?\s+cited/i,
  /^endnotes?\s*$/i,
  /^index\s*$/i,
  /^footnotes?\s*$/i,
  /^参考文献/,
  /^推荐阅读/,
  /^延伸阅读/,
  /^附录/,
  /^术语表/,
  /^词汇表/,
  /^词表/,
  /^注释/,
  /^索引/,
];

function shouldSkipSection(headingText: string): boolean {
  const cleaned = headingText.replace(/\*\*/g, "").replace(/\[.*?\]\(.*?\)/g, "").trim();
  return SKIP_SECTION_PATTERNS.some((p) => p.test(cleaned));
}

/**
 * Preprocess markdown content for TTS narration.
 * Strips metadata, converts structure to spoken-friendly text.
 * Skips reference sections, glossaries, appendices, etc.
 */
export function preprocessForAudio(mdContent: string): {
  text: string;
  chapters: { title: string; charOffset: number }[];
} {
  const lines = mdContent.split("\n");
  const outputLines: string[] = [];
  const chapters: { title: string; charOffset: number }[] = [];
  let currentCharOffset = 0;
  let skipMetadata = true;
  let skippingSection = false;

  for (const line of lines) {
    // Skip frontmatter block (title metadata)
    if (skipMetadata) {
      if (line.startsWith("---")) {
        skipMetadata = false;
        continue;
      }
      // Skip metadata lines like **Date:**, **For:**, **Slot:**, **Topic:**
      if (
        line.startsWith("**Date") ||
        line.startsWith("**日期") ||
        line.startsWith("**For:") ||
        line.startsWith("**写给") ||
        line.startsWith("**Slot:") ||
        line.startsWith("**Topic:") ||
        line.startsWith("**字数")
      ) {
        continue;
      }
      // Skip H1 title (already known from metadata)
      if (line.startsWith("# ")) {
        continue;
      }
    }

    // Check H2 headings for section skipping
    const h2Match = line.match(/^##\s+(.+)/);
    if (h2Match) {
      const title = h2Match[1]
        .replace(/\*\*/g, "")
        .replace(/\[.*?\]\(.*?\)/g, "")
        .trim();
      if (shouldSkipSection(title)) {
        skippingSection = true;
        continue;
      }
      skippingSection = false;
      chapters.push({ title, charOffset: currentCharOffset });
      outputLines.push("", `${title}。`, "");
      currentCharOffset += title.length + 4;
      continue;
    }

    // Check H3 — if a new H3 appears while skipping, check if it's also skippable
    const h3Match = line.match(/^###\s+(.+)/);
    if (h3Match) {
      if (skippingSection) continue;
      const subtitle = h3Match[1].replace(/\*\*/g, "").trim();
      if (shouldSkipSection(subtitle)) {
        skippingSection = true;
        continue;
      }
      outputLines.push("", `${subtitle}。`, "");
      currentCharOffset += subtitle.length + 4;
      continue;
    }

    // Skip all content in skipped sections
    if (skippingSection) continue;

    // Skip H4+ headings, just use them as text
    const h4Match = line.match(/^#{4,}\s+(.+)/);
    if (h4Match) {
      outputLines.push(h4Match[1].replace(/\*\*/g, "").trim());
      currentCharOffset += h4Match[1].length + 1;
      continue;
    }

    // Skip horizontal rules
    if (/^---+$/.test(line.trim())) continue;

    // Skip code blocks
    if (line.trim().startsWith("```")) continue;

    // Strip markdown formatting
    let processed = line
      .replace(/\*\*(.+?)\*\*/g, "$1") // bold
      .replace(/\*(.+?)\*/g, "$1") // italic
      .replace(/`(.+?)`/g, "$1") // inline code
      .replace(/\[(.+?)\]\(.+?\)/g, "$1") // links
      .replace(/!\[.*?\]\(.*?\)/g, "") // images
      .replace(/^\s*[-*+]\s+/, "") // unordered list bullets -> plain text
      .replace(/^\s*\d+\.\s+/, "") // ordered list numbers -> plain text
      .replace(/^\s*>\s+/, "") // blockquote markers
      .trim();

    // Handle tables: skip header separator rows, convert data rows
    if (/^\|[-:\s|]+\|$/.test(processed)) continue;
    if (processed.startsWith("|") && processed.endsWith("|")) {
      processed = processed
        .slice(1, -1)
        .split("|")
        .map((c) => c.trim())
        .filter((c) => c.length > 0)
        .join(", ");
    }

    // Handle LaTeX-like math
    processed = processed
      .replace(/\$(.+?)\$/g, (_, math) => {
        return math
          .replace(/\\frac\{(.+?)\}\{(.+?)\}/g, "$1 over $2")
          .replace(/\\sqrt\{(.+?)\}/g, "square root of $1")
          .replace(/\\sum/g, "sum of")
          .replace(/\\int/g, "integral of")
          .replace(/\^(\w)/g, " to the power of $1")
          .replace(/_(\w)/g, " sub $1");
      })
      .trim();

    if (processed.length > 0) {
      outputLines.push(processed);
      currentCharOffset += processed.length + 1;
    }
  }

  return {
    text: outputLines.join("\n"),
    chapters,
  };
}

/**
 * Split text into chunks suitable for OpenAI TTS API (max 4096 chars).
 * Splits at paragraph boundaries.
 */
export function chunkText(
  text: string,
  maxChunkSize: number = 3500
): string[] {
  const paragraphs = text.split(/\n\n+/);
  const chunks: string[] = [];
  let current = "";

  for (const para of paragraphs) {
    if (para.trim().length === 0) continue;

    if (current.length + para.length + 2 > maxChunkSize) {
      if (current.length > 0) {
        chunks.push(current.trim());
        current = "";
      }
      // If a single paragraph exceeds the limit, split by sentences
      if (para.length > maxChunkSize) {
        const sentences = para.match(/[^。！？.!?]+[。！？.!?]+/g) || [para];
        for (const sentence of sentences) {
          if (current.length + sentence.length > maxChunkSize) {
            if (current.length > 0) {
              chunks.push(current.trim());
              current = "";
            }
          }
          current += sentence;
        }
      } else {
        current = para;
      }
    } else {
      current += (current.length > 0 ? "\n\n" : "") + para;
    }
  }

  if (current.trim().length > 0) {
    chunks.push(current.trim());
  }

  return chunks;
}

/**
 * Generate audio for a single chunk using OpenAI TTS API.
 */
export async function generateChunkAudio(
  text: string,
  apiKey: string,
  voice: string = "nova",
  model: string = "tts-1-hd"
): Promise<Buffer> {
  const response = await fetch("https://api.openai.com/v1/audio/speech", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: text,
      voice,
      response_format: "mp3",
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI TTS error: ${response.status} - ${error}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

/**
 * Get audio directory for a book.
 */
export function getAudioDir(bookId: string): string {
  const dir = path.join(AUDIO_DIR, bookId);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  return dir;
}

/**
 * Read manifest for a book's audio.
 */
export function getAudioManifest(bookId: string): Record<string, unknown> | null {
  const manifestPath = path.join(AUDIO_DIR, bookId, "manifest.json");
  if (!fs.existsSync(manifestPath)) return null;
  const raw = JSON.parse(fs.readFileSync(manifestPath, "utf-8"));
  // Normalize: ensure streaming fields always present
  const chunks = raw.chunks || [];
  return {
    ...raw,
    complete: raw.complete ?? true,
    chunksTotal: raw.chunksTotal ?? chunks.length,
    chunksReady: raw.chunksReady ?? chunks.length,
    estimatedTotalDuration: raw.estimatedTotalDuration ?? raw.totalDuration ?? 0,
  };
}

/**
 * Get the path of an audio chunk.
 */
export function getAudioChunkPath(bookId: string, chunkIndex: number): string {
  return path.join(AUDIO_DIR, bookId, `chunk_${String(chunkIndex).padStart(3, "0")}.mp3`);
}

/**
 * Create a condensed spoken summary (~10 min) of a book using Anthropic API.
 * Used for "short" audio mode.
 */
export async function summarizeForAudio(
  mdContent: string,
  anthropicApiKey: string
): Promise<{ text: string; chapters: { title: string; charOffset: number }[] }> {
  // First preprocess to get clean text (with section skipping)
  const { text: fullText } = preprocessForAudio(mdContent);

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": anthropicApiKey,
      "content-type": "application/json",
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: `You are creating a condensed spoken summary of a book for audio narration.
The summary should be about 2000 words (approximately 10 minutes when read aloud).
Write it as natural, flowing narration — NOT bullet points.
Include the key insights, main arguments, and most important examples.
Write in the same language as the source text.
Do NOT include section headers — just flowing prose with natural transitions.
Start directly with the content, do NOT add a preamble like "This book is about..." or "Here is a summary...".

Here is the text to summarize:

${fullText.slice(0, 80000)}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Anthropic API error: ${response.status} - ${errText}`);
  }

  const data = await response.json();
  const summaryText = data.content[0].text;

  return {
    text: summaryText,
    chapters: [{ title: "Summary", charOffset: 0 }],
  };
}
