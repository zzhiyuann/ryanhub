"use client";

import { useState } from "react";
import { Library } from "@/components/library";
import { QueueManager } from "@/components/queue-manager";
import { Settings } from "@/components/settings";
import { BookReader } from "@/components/book-reader";
import { MiniPlayer } from "@/components/mini-player";
import { AudioProvider, useAudio } from "@/lib/audio-context";

type Tab = "library" | "queue" | "settings";

interface AppShellProps {
  user: {
    id: string;
    username: string;
    display_name: string;
    has_openai_key: boolean;
    has_anthropic_key: boolean;
  };
  onLogout: () => void;
  onRefreshAuth: () => void;
}

export function AppShell(props: AppShellProps) {
  return (
    <AudioProvider>
      <AppShellInner {...props} />
    </AudioProvider>
  );
}

function AppShellInner({ user, onLogout, onRefreshAuth }: AppShellProps) {
  const [tab, setTab] = useState<Tab>("library");
  const [readingBookId, setReadingBookId] = useState<string | null>(null);
  const audio = useAudio();

  return (
    <div className="h-screen flex flex-col">
      {/* Top bar */}
      <header className="border-b border-default px-4 py-3 flex items-center justify-between shrink-0 bg-page">
        {readingBookId ? (
          <button
            onClick={() => setReadingBookId(null)}
            className="text-sm text-secondary hover:text-primary transition-colors"
          >
            ← Back
          </button>
        ) : (
          <h1 className="text-lg font-semibold tracking-tight">Book Factory</h1>
        )}
        <div className="flex items-center gap-3">
          <span className="text-xs text-muted">{user.display_name}</span>
          {!readingBookId && (
            <button
              onClick={onLogout}
              className="text-xs text-muted hover:text-primary transition-colors"
            >
              Sign out
            </button>
          )}
        </div>
      </header>

      {/* Main content — scrollable */}
      <main className={`flex-1 ${readingBookId ? "flex flex-col min-h-0" : "overflow-y-auto"}`}>
        {readingBookId ? (
          <BookReader
            bookId={readingBookId}
            hasOpenAiKey={user.has_openai_key}
          />
        ) : (
          <>
            {tab === "library" && (
              <Library
                onReadBook={(id) => setReadingBookId(id)}
                onPlayAudio={(bookId, title) =>
                  audio.startPlaying(bookId, title)
                }
                hasOpenAiKey={user.has_openai_key}
              />
            )}
            {tab === "queue" && <QueueManager />}
            {tab === "settings" && <Settings onUpdate={onRefreshAuth} />}
          </>
        )}
      </main>

      {/* Audio mini player — always visible when audio active */}
      <MiniPlayer />

      {/* Bottom tab bar — always pinned */}
      <nav className="border-t border-default flex shrink-0 bg-page">
        {([
          { key: "library", label: "Library", icon: "📚" },
          { key: "queue", label: "Queue", icon: "📋" },
          { key: "settings", label: "Settings", icon: "⚙️" },
        ] as const).map(({ key, label, icon }) => (
          <button
            key={key}
            onClick={() => {
              setTab(key);
              if (readingBookId) setReadingBookId(null);
            }}
            className={`flex-1 py-3 text-center text-xs font-medium transition-colors ${
              !readingBookId && tab === key
                ? "text-primary"
                : "text-muted hover:text-secondary"
            }`}
          >
            <span className="block text-lg mb-0.5">{icon}</span>
            {label}
          </button>
        ))}
      </nav>
    </div>
  );
}
