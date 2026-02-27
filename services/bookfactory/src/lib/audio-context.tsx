"use client";

import {
  createContext,
  useContext,
  useState,
  useRef,
  useCallback,
  useEffect,
  type ReactNode,
} from "react";

interface Manifest {
  totalDuration: number;
  estimatedTotalDuration?: number;
  voice: string;
  complete: boolean;
  chunksTotal: number;
  chunksReady: number;
  chapters: {
    title: string;
    startTime: number;
    endTime: number;
    startChunk: number;
    endChunk: number;
  }[];
  chunks: { index: number; duration: number }[];
}

interface AudioContextType {
  // What's playing
  bookId: string | null;
  bookTitle: string | null;
  manifest: Manifest | null;

  // Playback state
  isPlaying: boolean;
  buffering: boolean;
  currentTime: number;
  currentChunkIndex: number;
  speed: number;
  generating: boolean;
  genProgress: number;

  // Computed
  totalDuration: number;
  progress: number;
  availablePct: number;
  currentChapter: Manifest["chapters"][0] | undefined;

  // Actions
  startPlaying: (bookId: string, title: string) => void;
  togglePlay: () => void;
  seekTo: (time: number) => void;
  skip: (seconds: number) => void;
  changeSpeed: () => void;
  close: () => void;
  startGeneration: (bookId: string, title: string, hasKey: boolean, mode?: "long" | "short") => void;
  formatTime: (s: number) => string;
}

const Ctx = createContext<AudioContextType | null>(null);

export function useAudio() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useAudio must be used within AudioProvider");
  return ctx;
}

export function AudioProvider({ children }: { children: ReactNode }) {
  const [bookId, setBookId] = useState<string | null>(null);
  const [bookTitle, setBookTitle] = useState<string | null>(null);
  const [manifest, setManifest] = useState<Manifest | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [buffering, setBuffering] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [currentChunkIndex, setCurrentChunkIndex] = useState(0);
  const [speed, setSpeed] = useState(1);
  const [generating, setGenerating] = useState(false);
  const [genProgress, setGenProgress] = useState(0);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  const playingRef = useRef(false);
  const manifestPollRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const bufferPollRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const currentBookIdRef = useRef<string | null>(null);

  // Keep ref in sync
  useEffect(() => {
    currentBookIdRef.current = bookId;
  }, [bookId]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      audioRef.current?.pause();
      if (manifestPollRef.current) clearTimeout(manifestPollRef.current);
      if (bufferPollRef.current) clearTimeout(bufferPollRef.current);
    };
  }, []);

  const formatTime = useCallback((s: number) => {
    const m = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    return `${m}:${sec.toString().padStart(2, "0")}`;
  }, []);

  // Computed
  const totalDuration = manifest
    ? manifest.complete
      ? manifest.totalDuration
      : manifest.estimatedTotalDuration || manifest.totalDuration
    : 0;
  const progress = totalDuration > 0 ? currentTime / totalDuration : 0;
  const availablePct = manifest
    ? manifest.complete
      ? 100
      : (manifest.totalDuration /
          (manifest.estimatedTotalDuration || manifest.totalDuration)) *
        100
    : 0;
  const currentChapter = manifest?.chapters.find(
    (ch) => currentTime >= ch.startTime && currentTime < ch.endTime
  );

  // ---------- Manifest fetching ----------

  const fetchManifest = useCallback(
    async (bid: string) => {
      try {
        const res = await fetch(`/api/audiobook/${bid}/manifest`);
        if (!res.ok) return null;
        const data = await res.json();
        if (data.error) return null;
        // Only update if still the same book
        if (currentBookIdRef.current === bid) {
          setManifest(data);
        }
        return data as Manifest;
      } catch {
        return null;
      }
    },
    []
  );

  // ---------- Chunk playback ----------

  const getChunkUrl = useCallback(
    (bid: string, index: number) => `/api/audiobook/${bid}/chunk/${index}`,
    []
  );

  const playChunkFn = useCallback(
    async (bid: string, m: Manifest, index: number, spd: number) => {
      if (index >= m.chunksReady) {
        if (m.complete) {
          setIsPlaying(false);
          playingRef.current = false;
          return;
        }
        setBuffering(true);
        // Wait for chunk
        const waitPoll = async () => {
          const data = await fetchManifest(bid);
          if (data && data.chunksReady > index) {
            setBuffering(false);
            if (playingRef.current) {
              playChunkFn(bid, data, index, spd);
            }
            return;
          }
          if (data && data.complete && data.chunksReady <= index) {
            setBuffering(false);
            setIsPlaying(false);
            playingRef.current = false;
            return;
          }
          bufferPollRef.current = setTimeout(waitPoll, 1500);
        };
        bufferPollRef.current = setTimeout(waitPoll, 1500);
        return;
      }

      setBuffering(false);

      let base = 0;
      for (let i = 0; i < index; i++) base += m.chunks[i].duration;
      setCurrentChunkIndex(index);

      if (audioRef.current) audioRef.current.pause();

      const audio = new Audio(getChunkUrl(bid, index));
      audio.playbackRate = spd;
      audioRef.current = audio;

      audio.addEventListener("timeupdate", () => {
        setCurrentTime(base + audio.currentTime);
      });
      audio.addEventListener("ended", () => {
        if (playingRef.current) {
          // Re-read manifest from state
          setManifest((prev) => {
            if (prev) {
              playChunkFn(bid, prev, index + 1, spd);
            }
            return prev;
          });
        }
      });
      audio.addEventListener("error", () => {
        if (playingRef.current) {
          setManifest((prev) => {
            if (prev) playChunkFn(bid, prev, index + 1, spd);
            return prev;
          });
        }
      });

      try {
        await audio.play();
        setIsPlaying(true);
        playingRef.current = true;
      } catch (e) {
        console.error("Playback failed:", e);
      }
    },
    [fetchManifest, getChunkUrl]
  );

  // ---------- Seek ----------

  const seekTo = useCallback(
    (targetTime: number) => {
      if (!manifest || !bookId) return;
      let accumulated = 0;
      for (let i = 0; i < manifest.chunks.length; i++) {
        if (accumulated + manifest.chunks[i].duration > targetTime) {
          if (i >= manifest.chunksReady) return;
          const offset = targetTime - accumulated;
          setCurrentChunkIndex(i);
          setCurrentTime(targetTime);
          if (audioRef.current) audioRef.current.pause();

          const audio = new Audio(getChunkUrl(bookId, i));
          audio.playbackRate = speed;
          audioRef.current = audio;

          const acc = accumulated; // capture
          audio.addEventListener("loadedmetadata", () => {
            audio.currentTime = offset;
          });
          audio.addEventListener("timeupdate", () => {
            setCurrentTime(acc + audio.currentTime);
          });
          audio.addEventListener("ended", () => {
            if (playingRef.current) {
              setManifest((prev) => {
                if (prev) playChunkFn(bookId, prev, i + 1, speed);
                return prev;
              });
            }
          });

          if (playingRef.current) audio.play();
          return;
        }
        accumulated += manifest.chunks[i].duration;
      }
    },
    [manifest, bookId, speed, getChunkUrl, playChunkFn]
  );

  // ---------- Public actions ----------

  const startPlaying = useCallback(
    (bid: string, title: string) => {
      // Clean up previous
      audioRef.current?.pause();
      if (manifestPollRef.current) clearTimeout(manifestPollRef.current);
      if (bufferPollRef.current) clearTimeout(bufferPollRef.current);
      playingRef.current = false;

      setBookId(bid);
      setBookTitle(title);
      setCurrentTime(0);
      setCurrentChunkIndex(0);
      setIsPlaying(false);
      setBuffering(false);
      setManifest(null);
      setGenerating(false);

      // Fetch manifest and start playing
      (async () => {
        const m = await fetchManifest(bid);
        if (!m) return;
        if (m.chunksReady > 0) {
          playChunkFn(bid, m, 0, speed);
        }
        if (!m.complete) {
          // Poll for more chunks
          const poll = async () => {
            const data = await fetchManifest(bid);
            if (data?.complete) return;
            manifestPollRef.current = setTimeout(poll, 3000);
          };
          manifestPollRef.current = setTimeout(poll, 3000);
        }
      })();
    },
    [fetchManifest, playChunkFn, speed]
  );

  const togglePlay = useCallback(() => {
    if (!manifest || !bookId) return;
    if (isPlaying || buffering) {
      audioRef.current?.pause();
      setIsPlaying(false);
      setBuffering(false);
      playingRef.current = false;
      if (bufferPollRef.current) clearTimeout(bufferPollRef.current);
    } else {
      if (audioRef.current && audioRef.current.src) {
        audioRef.current.play();
        setIsPlaying(true);
        playingRef.current = true;
      } else {
        playChunkFn(bookId, manifest, currentChunkIndex, speed);
      }
    }
  }, [manifest, bookId, isPlaying, buffering, currentChunkIndex, speed, playChunkFn]);

  const skip = useCallback(
    (seconds: number) => {
      seekTo(Math.max(0, Math.min(currentTime + seconds, totalDuration)));
    },
    [seekTo, currentTime, totalDuration]
  );

  const changeSpeed = useCallback(() => {
    const speeds = [0.75, 1, 1.25, 1.5, 2];
    const next = speeds[(speeds.indexOf(speed) + 1) % speeds.length];
    setSpeed(next);
    if (audioRef.current) audioRef.current.playbackRate = next;
  }, [speed]);

  const close = useCallback(() => {
    audioRef.current?.pause();
    playingRef.current = false;
    if (manifestPollRef.current) clearTimeout(manifestPollRef.current);
    if (bufferPollRef.current) clearTimeout(bufferPollRef.current);
    setBookId(null);
    setBookTitle(null);
    setManifest(null);
    setIsPlaying(false);
    setBuffering(false);
    setCurrentTime(0);
    setCurrentChunkIndex(0);
    setGenerating(false);
    setGenProgress(0);
  }, []);

  const startGeneration = useCallback(
    (bid: string, title: string, hasKey: boolean, mode?: "long" | "short") => {
      if (!hasKey) {
        alert("Configure your OpenAI API key in Settings first.");
        return;
      }
      setBookId(bid);
      setBookTitle(title);
      setGenerating(true);
      setGenProgress(0);
      setManifest(null);

      (async () => {
        try {
          const res = await fetch("/api/audiobook/generate", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ bookId: bid, ...(mode ? { mode } : {}) }),
          });
          if (!res.ok) {
            const data = await res.json();
            alert(data.error || "Failed");
            setGenerating(false);
            return;
          }
          // Start polling
          const poll = async () => {
            const data = await fetchManifest(bid);
            if (data) {
              setGenProgress(data.chunksReady / data.chunksTotal);
              if (data.complete) {
                setGenerating(false);
                return;
              }
            }
            // Also check status
            try {
              const sr = await fetch(`/api/audiobook/${bid}/status`);
              const sd = await sr.json();
              if (sd.status === "error") {
                setGenerating(false);
                alert(`Audio generation failed: ${sd.error}`);
                return;
              }
              if (sd.status === "done") {
                setGenerating(false);
                await fetchManifest(bid);
                return;
              }
            } catch {
              /* ignore */
            }
            manifestPollRef.current = setTimeout(poll, 2000);
          };
          manifestPollRef.current = setTimeout(poll, 2000);
        } catch {
          setGenerating(false);
        }
      })();
    },
    [fetchManifest]
  );

  return (
    <Ctx.Provider
      value={{
        bookId,
        bookTitle,
        manifest,
        isPlaying,
        buffering,
        currentTime,
        currentChunkIndex,
        speed,
        generating,
        genProgress,
        totalDuration,
        progress,
        availablePct,
        currentChapter,
        startPlaying,
        togglePlay,
        seekTo,
        skip,
        changeSpeed,
        close,
        startGeneration,
        formatTime,
      }}
    >
      {children}
    </Ctx.Provider>
  );
}
