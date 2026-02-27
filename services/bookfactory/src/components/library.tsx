"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useBooks, Book } from "@/lib/hooks";

interface LibraryProps {
  onReadBook: (id: string) => void;
  onPlayAudio: (bookId: string, title: string) => void;
  hasOpenAiKey: boolean;
}

interface AudioProgress {
  progress: number; // 0-1
  chunksReady: number;
  chunksTotal: number;
}

export function Library({ onReadBook, onPlayAudio, hasOpenAiKey }: LibraryProps) {
  const { books, loading, refresh, scanBooks } = useBooks();
  const [scanning, setScanning] = useState(false);
  const [scanResult, setScanResult] = useState<{
    scanned: number;
    imported: number;
  } | null>(null);
  const [search, setSearch] = useState("");
  // Track generating books with progress info
  const [generatingAudio, setGeneratingAudio] = useState<Map<string, AudioProgress>>(
    new Map()
  );
  const [audioModeDialog, setAudioModeDialog] = useState<Book | null>(null);
  const pollTimers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());

  // On mount, check all books without audio for in-progress jobs
  useEffect(() => {
    if (books.length === 0) return;

    const booksWithoutAudio = books.filter((b) => b.has_audio !== 1);
    for (const book of booksWithoutAudio) {
      checkAudioStatus(book.id);
    }

    return () => {
      // Clear all poll timers on unmount
      for (const timer of pollTimers.current.values()) {
        clearTimeout(timer);
      }
    };
    // Only run once when books load
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [books.length > 0]);

  const checkAudioStatus = useCallback(async (bookId: string) => {
    try {
      const res = await fetch(`/api/audiobook/${bookId}/status`);
      const data = await res.json();
      if (data.status === "processing") {
        setGeneratingAudio((prev) => {
          const next = new Map(prev);
          next.set(bookId, {
            progress: data.progress || 0,
            chunksReady: data.chunksReady || 0,
            chunksTotal: data.chunksTotal || 0,
          });
          return next;
        });
        // Start polling
        startPolling(bookId);
      }
    } catch {
      // ignore
    }
  }, []);

  const startPolling = useCallback((bookId: string) => {
    // Clear existing timer for this book
    const existing = pollTimers.current.get(bookId);
    if (existing) clearTimeout(existing);

    const poll = async () => {
      try {
        const res = await fetch(`/api/audiobook/${bookId}/status`);
        const data = await res.json();

        if (data.status === "done") {
          setGeneratingAudio((prev) => {
            const next = new Map(prev);
            next.delete(bookId);
            return next;
          });
          pollTimers.current.delete(bookId);
          refresh();
          return;
        }

        if (data.status === "error") {
          setGeneratingAudio((prev) => {
            const next = new Map(prev);
            next.delete(bookId);
            return next;
          });
          pollTimers.current.delete(bookId);
          alert(`Audio generation failed: ${data.error}`);
          return;
        }

        // Update progress
        setGeneratingAudio((prev) => {
          const next = new Map(prev);
          next.set(bookId, {
            progress: data.progress || 0,
            chunksReady: data.chunksReady || 0,
            chunksTotal: data.chunksTotal || 0,
          });
          return next;
        });

        // Continue polling
        const timer = setTimeout(poll, 2000);
        pollTimers.current.set(bookId, timer);
      } catch {
        const timer = setTimeout(poll, 5000);
        pollTimers.current.set(bookId, timer);
      }
    };

    const timer = setTimeout(poll, 2000);
    pollTimers.current.set(bookId, timer);
  }, [refresh]);

  const filteredBooks = books.filter(
    (b) =>
      b.title.toLowerCase().includes(search.toLowerCase()) ||
      b.topic?.toLowerCase().includes(search.toLowerCase()) ||
      b.date.includes(search)
  );

  // Group books by date
  const grouped = filteredBooks.reduce(
    (acc, book) => {
      const date = book.date;
      if (!acc[date]) acc[date] = [];
      acc[date].push(book);
      return acc;
    },
    {} as Record<string, Book[]>
  );

  const sortedDates = Object.keys(grouped).sort((a, b) => b.localeCompare(a));

  const handleScan = async () => {
    setScanning(true);
    setScanResult(null);
    try {
      const result = await scanBooks();
      setScanResult(result);
    } catch (e) {
      console.error(e);
    } finally {
      setScanning(false);
    }
  };

  const handleGenerateAudio = async (book: Book, mode: "long" | "short") => {
    if (!hasOpenAiKey) {
      alert("Configure your OpenAI API key in Settings first.");
      return;
    }

    // Optimistically show generating state
    setGeneratingAudio((prev) => {
      const next = new Map(prev);
      next.set(book.id, { progress: 0, chunksReady: 0, chunksTotal: 0 });
      return next;
    });

    try {
      const res = await fetch("/api/audiobook/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ bookId: book.id, mode }),
      });
      if (!res.ok) {
        const data = await res.json();
        setGeneratingAudio((prev) => {
          const next = new Map(prev);
          next.delete(book.id);
          return next;
        });
        alert(data.error || "Failed to start audio generation");
        return;
      }
      const data = await res.json();
      setGeneratingAudio((prev) => {
        const next = new Map(prev);
        next.set(book.id, {
          progress: 0,
          chunksReady: 0,
          chunksTotal: data.chunksTotal || 0,
        });
        return next;
      });
      startPolling(book.id);
    } catch {
      setGeneratingAudio((prev) => {
        const next = new Map(prev);
        next.delete(book.id);
        return next;
      });
    }
  };

  const formatWordCount = (count: number) => {
    if (count >= 10000) return `${(count / 10000).toFixed(1)}万字`;
    if (count >= 1000) return `${(count / 1000).toFixed(1)}k words`;
    return `${count} words`;
  };

  const formatDuration = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    return `${m} min`;
  };

  if (loading) {
    return (
      <div className="p-6 text-center text-muted">Loading library...</div>
    );
  }

  return (
    <div className="p-4 pb-4 max-w-4xl mx-auto">
      {/* Header row */}
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold">Library</h2>
        <button
          onClick={handleScan}
          disabled={scanning}
          className="text-xs px-3 py-1.5 bg-secondary hover:bg-tertiary rounded-lg transition-colors disabled:opacity-50"
        >
          {scanning ? "Scanning..." : "Scan Books"}
        </button>
      </div>

      {scanResult && (
        <div className="mb-4 text-xs bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-900/50 rounded-lg px-3 py-2 text-emerald-700 dark:text-emerald-300">
          Scanned {scanResult.scanned} files, imported {scanResult.imported} new
          books.
        </div>
      )}

      {/* Search */}
      <input
        type="text"
        placeholder="Search books..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="w-full px-3 py-2 mb-4 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
      />

      {books.length === 0 ? (
        <div className="text-center py-16 text-muted">
          <p className="text-lg mb-2">No books yet</p>
          <p className="text-sm">
            Click &ldquo;Scan Books&rdquo; to import existing books from your bookfactory
            directory.
          </p>
        </div>
      ) : (
        sortedDates.map((date) => (
          <div key={date} className="mb-6">
            <h3 className="text-xs font-medium text-muted mb-2 sticky top-0 bg-page py-1">
              {date}
            </h3>
            <div className="space-y-2">
              {grouped[date].map((book) => {
                const audioProgress = generatingAudio.get(book.id);
                const isGenerating = audioProgress !== undefined;
                const progressPct = audioProgress
                  ? Math.round(audioProgress.progress * 100)
                  : 0;

                return (
                  <div
                    key={book.id}
                    className="bg-card border border-default rounded-xl p-4 hover:bg-card-hover transition-colors group"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div
                        className="flex-1 cursor-pointer"
                        onClick={() => onReadBook(book.id)}
                      >
                        <h4 className="font-medium text-sm leading-snug group-hover:text-primary transition-colors">
                          {book.title}
                        </h4>
                        {book.topic && (
                          <p className="text-xs text-muted mt-1 truncate">
                            {book.topic}
                          </p>
                        )}
                        <div className="flex items-center gap-3 mt-2 text-xs text-muted">
                          <span>{formatWordCount(book.word_count)}</span>
                          {book.slot && <span>{book.slot}</span>}
                          {book.has_audio === 1 && book.audio_duration && (
                            <span className="text-amber-600 dark:text-amber-400">
                              🎧 {formatDuration(book.audio_duration)}
                            </span>
                          )}
                        </div>
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                        {book.has_audio === 1 ? (
                          <button
                            onClick={() => onPlayAudio(book.id, book.title)}
                            className="px-3 py-1.5 bg-amber-600 hover:bg-amber-700 text-white text-xs font-medium rounded-lg transition-colors"
                          >
                            Play
                          </button>
                        ) : isGenerating ? (
                          <div className="flex items-center gap-2">
                            <div className="w-16 h-1.5 bg-secondary rounded-full overflow-hidden">
                              <div
                                className="h-full bg-amber-500 transition-all duration-500"
                                style={{ width: `${progressPct}%` }}
                              />
                            </div>
                            <span className="text-xs text-muted tabular-nums">
                              {progressPct}%
                            </span>
                          </div>
                        ) : (
                          <button
                            onClick={() => {
                              if (!hasOpenAiKey) {
                                alert("Configure your OpenAI API key in Settings first.");
                                return;
                              }
                              setAudioModeDialog(book);
                            }}
                            className="px-3 py-1.5 bg-secondary hover:bg-tertiary text-xs rounded-lg transition-colors"
                            title={
                              hasOpenAiKey
                                ? "Generate audiobook"
                                : "Configure OpenAI key first"
                            }
                          >
                            🎙 Audio
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        ))
      )}
      {/* Audio mode selection dialog */}
      {audioModeDialog && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
          onClick={() => setAudioModeDialog(null)}
        >
          <div
            className="bg-card border border-default rounded-xl p-5 w-80 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-sm font-semibold mb-1">Generate Audio</h3>
            <p className="text-xs text-muted mb-4 truncate">
              {audioModeDialog.title}
            </p>
            <div className="space-y-2">
              <button
                onClick={() => {
                  const book = audioModeDialog;
                  setAudioModeDialog(null);
                  handleGenerateAudio(book, "long");
                }}
                className="w-full text-left px-4 py-3 bg-secondary hover:bg-tertiary rounded-lg transition-colors"
              >
                <div className="text-sm font-medium">Full Book</div>
                <div className="text-xs text-muted mt-0.5">
                  Full narration, skipping references
                </div>
              </button>
              <button
                onClick={() => {
                  const book = audioModeDialog;
                  setAudioModeDialog(null);
                  handleGenerateAudio(book, "short");
                }}
                className="w-full text-left px-4 py-3 bg-secondary hover:bg-tertiary rounded-lg transition-colors"
              >
                <div className="text-sm font-medium">Summary (~10 min)</div>
                <div className="text-xs text-muted mt-0.5">
                  AI-condensed version of the book
                </div>
              </button>
            </div>
            <button
              onClick={() => setAudioModeDialog(null)}
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
