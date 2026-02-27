"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useAudio } from "@/lib/audio-context";

interface BookReaderProps {
  bookId: string;
  hasOpenAiKey: boolean;
}

export function BookReader({ bookId, hasOpenAiKey }: BookReaderProps) {
  const audio = useAudio();
  const [html, setHtml] = useState<string>("");
  const [book, setBook] = useState<{
    title: string;
    has_audio: number;
    word_count: number;
  } | null>(null);
  const [loading, setLoading] = useState(true);
  const [hasAudio, setHasAudio] = useState(false);
  const [checkingAudio, setCheckingAudio] = useState(true);

  const [audioModeDialog, setAudioModeDialog] = useState(false);

  const contentRef = useRef<HTMLDivElement | null>(null);
  const [activeSentenceIdx, setActiveSentenceIdx] = useState<number | null>(
    null
  );

  // Sentence timing map
  const sentenceTimings = useRef<{ startTime: number; endTime: number }[]>([]);

  // Is the shared audio context playing THIS book?
  const isAudioForThisBook = audio.bookId === bookId;
  const manifest = isAudioForThisBook ? audio.manifest : null;
  const currentTime = isAudioForThisBook ? audio.currentTime : 0;

  // ---------- Load book + check audio state ----------

  useEffect(() => {
    setLoading(true);
    setCheckingAudio(true);

    Promise.all([
      fetch(`/api/books/${bookId}`).then((r) => r.json()),
      fetch(`/api/books/${bookId}/content?format=html`).then((r) => r.text()),
    ]).then(([bookData, htmlContent]) => {
      setBook(bookData.book);
      setHtml(htmlContent);
      setLoading(false);
      setHasAudio(bookData.book.has_audio === 1);

      // Also check audio status endpoint (catches in-progress generation)
      if (bookData.book.has_audio !== 1) {
        fetch(`/api/audiobook/${bookId}/status`)
          .then((r) => r.json())
          .then((data) => {
            if (data.status === "processing") {
              // Audio is being generated — start playing via shared context
              // which will pick up chunks as they come
              setHasAudio(false);
            } else if (data.status === "done") {
              setHasAudio(true);
            }
          })
          .catch(() => {})
          .finally(() => setCheckingAudio(false));
      } else {
        setCheckingAudio(false);
      }
    });
  }, [bookId]);

  // Rebuild sentence timings whenever manifest updates or html changes
  useEffect(() => {
    if (!manifest || !contentRef.current) return;
    buildSentenceTimings();
  }, [manifest?.chunks.length, html]);

  // ---------- Sentence timings ----------

  const buildSentenceTimings = () => {
    if (!manifest || !contentRef.current) return;

    const el = contentRef.current;
    const paragraphs = el.querySelectorAll("p, li, h2, h3, blockquote");

    const totalDuration =
      manifest.estimatedTotalDuration || manifest.totalDuration;
    if (totalDuration <= 0) return;

    let totalTextLength = 0;
    const paraInfos: { el: Element; len: number }[] = [];

    paragraphs.forEach((p) => {
      const len = (p.textContent || "").length;
      if (len > 0) {
        paraInfos.push({ el: p, len });
        totalTextLength += len;
      }
    });

    if (totalTextLength === 0) return;

    const timings: { startTime: number; endTime: number }[] = [];
    let accumulatedTime = 0;

    for (let i = 0; i < paraInfos.length; i++) {
      const para = paraInfos[i];
      const duration = (para.len / totalTextLength) * totalDuration;
      timings.push({
        startTime: accumulatedTime,
        endTime: accumulatedTime + duration,
      });
      para.el.setAttribute("data-sentence-idx", String(i));
      para.el.classList.add(
        "transition-colors",
        "duration-300",
        "rounded",
        "cursor-pointer"
      );
      accumulatedTime += duration;
    }

    sentenceTimings.current = timings;
  };

  // ---------- Highlight + auto-scroll ----------

  useEffect(() => {
    if (!manifest || !contentRef.current) return;

    const timings = sentenceTimings.current;
    let newIdx: number | null = null;

    for (let i = 0; i < timings.length; i++) {
      if (
        currentTime >= timings[i].startTime &&
        currentTime < timings[i].endTime
      ) {
        newIdx = i;
        break;
      }
    }

    if (newIdx !== activeSentenceIdx) {
      if (activeSentenceIdx !== null) {
        const oldEl = contentRef.current.querySelector(
          `[data-sentence-idx="${activeSentenceIdx}"]`
        );
        if (oldEl) {
          oldEl.classList.remove(
            "bg-amber-100",
            "dark:bg-amber-900/30",
            "-mx-1",
            "px-1"
          );
        }
      }
      if (newIdx !== null) {
        const newEl = contentRef.current.querySelector(
          `[data-sentence-idx="${newIdx}"]`
        );
        if (newEl) {
          newEl.classList.add(
            "bg-amber-100",
            "dark:bg-amber-900/30",
            "-mx-1",
            "px-1"
          );
          const rect = newEl.getBoundingClientRect();
          const container = contentRef.current.closest("main");
          if (container) {
            const containerRect = container.getBoundingClientRect();
            if (
              rect.top < containerRect.top + 60 ||
              rect.bottom > containerRect.bottom - 100
            ) {
              newEl.scrollIntoView({ behavior: "smooth", block: "center" });
            }
          }
        }
      }
      setActiveSentenceIdx(newIdx);
    }
  }, [currentTime, activeSentenceIdx, manifest]);

  // ---------- Click sentence to seek ----------

  const handleContentClick = useCallback(
    (e: React.MouseEvent) => {
      if (!manifest || !isAudioForThisBook) return;
      const target = e.target as HTMLElement;
      const sentenceEl = target.closest(
        "[data-sentence-idx]"
      ) as HTMLElement | null;
      if (!sentenceEl) return;

      const idx = parseInt(
        sentenceEl.getAttribute("data-sentence-idx") || ""
      );
      if (isNaN(idx) || !sentenceTimings.current[idx]) return;

      const targetTime = sentenceTimings.current[idx].startTime;
      audio.seekTo(targetTime);
      // Auto-play if not playing
      if (!audio.isPlaying) {
        audio.togglePlay();
      }
    },
    [manifest, isAudioForThisBook, audio]
  );

  // ---------- Generate audio handler ----------

  const handleGenerateAudio = () => {
    if (!book) return;
    if (!hasOpenAiKey) {
      alert("Configure your OpenAI API key in Settings first.");
      return;
    }
    setAudioModeDialog(true);
  };

  const handleStartGenerationWithMode = (mode: "long" | "short") => {
    if (!book) return;
    setAudioModeDialog(false);
    audio.startGeneration(bookId, book.title, hasOpenAiKey, mode);
  };

  // ---------- Auto-start playback when book has audio ----------

  useEffect(() => {
    if (!book) return;
    const bookHasAudio = hasAudio || book.has_audio === 1;
    if (!bookHasAudio) return;
    // Don't auto-start if already playing this book or generating
    if (isAudioForThisBook) return;
    if (audio.generating && audio.bookId === bookId) return;
    audio.startPlaying(bookId, book.title);
  }, [book, hasAudio, bookId, isAudioForThisBook, audio]);

  // ---------- Render ----------

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20 text-muted">
        Loading book...
      </div>
    );
  }

  // Determine audio state for this book
  const isGeneratingThisBook =
    audio.generating && audio.bookId === bookId;
  const showAudioPlayer = isAudioForThisBook && manifest && manifest.chunksReady > 0;
  const bookHasAudio = hasAudio || (!checkingAudio && book?.has_audio === 1);
  const showGenerateButton = !checkingAudio && !bookHasAudio && !isGeneratingThisBook;

  return (
    <div className="flex flex-col h-full">
      {/* Generate audio button — only when book has no audio and not generating */}
      {showGenerateButton && (
        <div className="flex items-center justify-end px-4 py-2 border-b border-default shrink-0 bg-page">
          <button
            onClick={handleGenerateAudio}
            className="px-3 py-1.5 bg-secondary hover:bg-tertiary text-xs rounded-lg transition-colors"
          >
            Generate Audio
          </button>
        </div>
      )}

      {/* Book content — scrollable */}
      <div className="flex-1 overflow-y-auto">
        <div
          ref={contentRef}
          onClick={showAudioPlayer ? handleContentClick : undefined}
          className="max-w-3xl mx-auto px-4 py-8
            [&_h1]:text-xl [&_h1]:font-bold [&_h1]:mb-4
            [&_h2]:text-lg [&_h2]:font-semibold [&_h2]:mt-8 [&_h2]:mb-3
            [&_h3]:text-base [&_h3]:font-medium [&_h3]:mt-6 [&_h3]:mb-2
            [&_p]:leading-relaxed [&_p]:mb-3 [&_p]:text-sm
            [&_blockquote]:border-l-2 [&_blockquote]:border-default [&_blockquote]:pl-4 [&_blockquote]:italic [&_blockquote]:text-secondary
            [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5
            [&_li]:mb-1 [&_li]:text-sm
            [&_strong]:font-semibold
            [&_hr]:border-default [&_hr]:my-8
            [&_a]:text-amber-600 [&_a]:underline"
          dangerouslySetInnerHTML={{ __html: html }}
        />
      </div>

      {/* Audio mode selection dialog */}
      {audioModeDialog && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
          onClick={() => setAudioModeDialog(false)}
        >
          <div
            className="bg-card border border-default rounded-xl p-5 w-80 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-sm font-semibold mb-1">Generate Audio</h3>
            <p className="text-xs text-muted mb-4 truncate">
              {book?.title}
            </p>
            <div className="space-y-2">
              <button
                onClick={() => handleStartGenerationWithMode("long")}
                className="w-full text-left px-4 py-3 bg-secondary hover:bg-tertiary rounded-lg transition-colors"
              >
                <div className="text-sm font-medium">Full Book</div>
                <div className="text-xs text-muted mt-0.5">
                  Full narration, skipping references
                </div>
              </button>
              <button
                onClick={() => handleStartGenerationWithMode("short")}
                className="w-full text-left px-4 py-3 bg-secondary hover:bg-tertiary rounded-lg transition-colors"
              >
                <div className="text-sm font-medium">Summary (~10 min)</div>
                <div className="text-xs text-muted mt-0.5">
                  AI-condensed version of the book
                </div>
              </button>
            </div>
            <button
              onClick={() => setAudioModeDialog(false)}
              className="w-full mt-3 text-xs text-muted hover:text-primary text-center py-1.5 transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
