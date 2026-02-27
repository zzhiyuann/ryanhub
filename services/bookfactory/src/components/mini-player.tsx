"use client";

import { useState, useCallback } from "react";
import { useAudio } from "@/lib/audio-context";

/**
 * Hook that returns [isFlashing, triggerFlash] for brief visual feedback.
 * When triggered, sets state to true for ~150ms then resets.
 */
function useFlash(duration = 150): [boolean, () => void] {
  const [flashing, setFlashing] = useState(false);
  const trigger = useCallback(() => {
    setFlashing(true);
    setTimeout(() => setFlashing(false), duration);
  }, [duration]);
  return [flashing, trigger];
}

export function MiniPlayer() {
  const audio = useAudio();
  const [expanded, setExpanded] = useState(false);

  // Flash states for all 4 skip buttons (2 mini, 2 expanded)
  const [miniBackFlash, triggerMiniBack] = useFlash();
  const [miniFwdFlash, triggerMiniFwd] = useFlash();
  const [expBackFlash, triggerExpBack] = useFlash();
  const [expFwdFlash, triggerExpFwd] = useFlash();

  // Don't render if no audio loaded
  if (!audio.bookId || !audio.bookTitle) return null;

  // Still generating with no audio yet? Show generation progress bar
  if (audio.generating && (!audio.manifest || audio.manifest.chunksReady === 0)) {
    return (
      <div className="border-t border-default bg-page/95 backdrop-blur shrink-0">
        <div className="flex items-center gap-3 px-4 py-2">
          <div className="w-8 h-8 flex items-center justify-center bg-amber-600/20 rounded-full shrink-0">
            <span className="text-xs animate-pulse">🎙</span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-medium truncate">{audio.bookTitle}</p>
            <div className="flex items-center gap-2 mt-1">
              <div className="flex-1 h-1.5 bg-secondary rounded-full overflow-hidden">
                <div
                  className="h-full bg-amber-500 transition-all duration-500"
                  style={{ width: `${audio.genProgress * 100}%` }}
                />
              </div>
              <span className="text-xs text-muted tabular-nums">
                {Math.round(audio.genProgress * 100)}%
              </span>
            </div>
          </div>
          <button
            onClick={audio.close}
            className="text-muted hover:text-primary text-xs shrink-0"
          >
            ✕
          </button>
        </div>
      </div>
    );
  }

  // No manifest at all
  if (!audio.manifest) return null;

  // Expanded full-screen player
  if (expanded) {
    return (
      <div className="fixed inset-0 bg-page z-50 flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-default shrink-0">
          <button
            onClick={() => setExpanded(false)}
            className="text-xs text-secondary hover:text-primary transition-colors"
          >
            ▾ Minimize
          </button>
          <button
            onClick={() => { setExpanded(false); audio.close(); }}
            className="text-xs text-secondary hover:text-primary transition-colors"
          >
            Close
          </button>
        </div>

        {/* Cover + info */}
        <div className="flex-1 flex flex-col items-center justify-center px-8">
          <div className="w-48 h-48 bg-gradient-to-br from-amber-600 to-orange-800 rounded-2xl flex items-center justify-center mb-8 shadow-2xl">
            <span className="text-4xl">📖</span>
          </div>
          <h2 className="text-lg font-semibold text-center mb-1 max-w-sm">
            {audio.bookTitle}
          </h2>
          <p className="text-xs text-muted">
            {audio.currentChapter?.title || ""}
          </p>
          {audio.generating && !audio.manifest?.complete && (
            <p className="text-xs text-amber-500 mt-1 animate-pulse">
              Generating {audio.manifest!.chunksReady}/{audio.manifest!.chunksTotal}...
            </p>
          )}
        </div>

        {/* Controls */}
        <div className="px-8 pb-8 space-y-4">
          {/* Seekable range slider */}
          <div className="space-y-1">
            <input
              type="range"
              min={0}
              max={audio.totalDuration || 1}
              step={0.5}
              value={audio.currentTime}
              onChange={(e) => audio.seekTo(parseFloat(e.target.value))}
              className="w-full h-1 appearance-none bg-secondary rounded-full cursor-pointer
                [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-3 [&::-webkit-slider-thumb]:h-3
                [&::-webkit-slider-thumb]:bg-amber-600 [&::-webkit-slider-thumb]:rounded-full
                [&::-webkit-slider-thumb]:shadow-md"
              style={{
                background: `linear-gradient(to right, #d97706 ${audio.progress * 100}%, var(--bg-secondary) ${audio.progress * 100}%)`,
              }}
            />
            <div className="flex justify-between text-xs text-muted">
              <span>{audio.formatTime(audio.currentTime)}</span>
              <span>{audio.formatTime(audio.totalDuration)}</span>
            </div>
          </div>

          {/* Play controls */}
          <div className="flex items-center justify-center gap-8">
            <button
              onClick={() => { audio.skip(-15); triggerExpBack(); }}
              className={`text-secondary hover:text-primary text-sm px-3 py-2 rounded-lg active:scale-90 transition-all select-none ${expBackFlash ? "bg-amber-500/30" : ""}`}
            >
              -15s
            </button>
            <button
              onClick={audio.togglePlay}
              className="w-14 h-14 flex items-center justify-center bg-amber-600 text-white rounded-full text-xl font-bold hover:bg-amber-700 active:scale-95 transition-all"
            >
              {audio.buffering ? (
                <span className="animate-pulse text-sm">···</span>
              ) : audio.isPlaying ? "⏸" : "▶"}
            </button>
            <button
              onClick={() => { audio.skip(15); triggerExpFwd(); }}
              className={`text-secondary hover:text-primary text-sm px-3 py-2 rounded-lg active:scale-90 transition-all select-none ${expFwdFlash ? "bg-amber-500/30" : ""}`}
            >
              +15s
            </button>
          </div>

          {/* Speed */}
          <div className="flex justify-center">
            <button
              onClick={audio.changeSpeed}
              className="px-4 py-1 bg-secondary hover:bg-tertiary rounded-full text-xs font-medium transition-colors"
            >
              {audio.speed}x
            </button>
          </div>

          {/* Chapter list */}
          {audio.manifest!.chapters.length > 0 && (
            <div className="max-h-40 overflow-y-auto border border-default rounded-xl">
              {audio.manifest!.chapters.map((ch, i) => (
                <button
                  key={i}
                  onClick={() => audio.seekTo(ch.startTime)}
                  className={`w-full text-left px-4 py-2 text-xs flex justify-between items-center hover:bg-card-hover transition-colors ${
                    audio.currentChapter?.title === ch.title
                      ? "text-amber-600 dark:text-amber-400 bg-card"
                      : "text-secondary"
                  }`}
                >
                  <span className="truncate mr-2">{ch.title}</span>
                  <span className="text-muted shrink-0">
                    {audio.formatTime(ch.startTime)}
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  // Mini player bar
  return (
    <div className="border-t border-default bg-page/95 backdrop-blur shrink-0 z-40">
      {/* Clickable progress bar */}
      <div
        className="h-1 bg-secondary cursor-pointer relative group"
        onClick={(e) => {
          const rect = e.currentTarget.getBoundingClientRect();
          const pct = (e.clientX - rect.left) / rect.width;
          audio.seekTo(pct * audio.totalDuration);
        }}
      >
        {/* Available region (when streaming) */}
        {!audio.manifest?.complete && (
          <div
            className="absolute inset-y-0 left-0 bg-amber-200/30 dark:bg-amber-800/20"
            style={{ width: `${audio.availablePct}%` }}
          />
        )}
        {/* Played region */}
        <div
          className="h-full bg-amber-500 transition-all duration-200 relative z-10"
          style={{ width: `${audio.progress * 100}%` }}
        />
        {/* Scrub handle */}
        <div
          className="absolute top-1/2 -translate-y-1/2 w-3 h-3 bg-amber-500 rounded-full shadow opacity-0 group-hover:opacity-100 transition-opacity z-20"
          style={{ left: `${audio.progress * 100}%`, marginLeft: "-6px" }}
        />
      </div>

      <div className="flex items-center gap-3 px-4 py-2">
        <button
          onClick={audio.togglePlay}
          className="w-8 h-8 flex items-center justify-center bg-amber-600 text-white rounded-full shrink-0 text-sm font-bold"
        >
          {audio.buffering ? (
            <span className="animate-pulse text-xs">···</span>
          ) : audio.isPlaying ? "⏸" : "▶"}
        </button>
        <div
          className="flex-1 min-w-0 cursor-pointer"
          onClick={() => setExpanded(true)}
        >
          <p className="text-xs font-medium truncate">{audio.bookTitle}</p>
          <p className="text-xs text-muted truncate">
            {audio.currentChapter?.title || ""}
            {" · "}
            {audio.formatTime(audio.currentTime)} / {audio.formatTime(audio.totalDuration)}
          </p>
        </div>
        <div className="flex items-center gap-1 shrink-0">
          <button
            onClick={() => { audio.skip(-15); triggerMiniBack(); }}
            className={`text-xs text-secondary hover:text-primary px-1 py-1 rounded active:scale-90 transition-all select-none ${miniBackFlash ? "bg-amber-500/30" : ""}`}
          >
            -15s
          </button>
          <button
            onClick={() => { audio.skip(15); triggerMiniFwd(); }}
            className={`text-xs text-secondary hover:text-primary px-1 py-1 rounded active:scale-90 transition-all select-none ${miniFwdFlash ? "bg-amber-500/30" : ""}`}
          >
            +15s
          </button>
          <button
            onClick={audio.changeSpeed}
            className="px-2 py-0.5 bg-secondary hover:bg-tertiary rounded text-xs font-medium transition-colors ml-1"
          >
            {audio.speed}x
          </button>
          <button
            onClick={audio.close}
            className="text-muted hover:text-primary text-xs ml-1"
          >
            ✕
          </button>
        </div>
      </div>
    </div>
  );
}
