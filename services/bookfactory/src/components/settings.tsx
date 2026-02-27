"use client";

import { useState, useEffect } from "react";

interface SettingsProps {
  onUpdate: () => void;
}

export function Settings({ onUpdate }: SettingsProps) {
  const [openaiKey, setOpenaiKey] = useState("");
  const [anthropicKey, setAnthropicKey] = useState("");
  const [hasOpenaiKey, setHasOpenaiKey] = useState(false);
  const [hasAnthropicKey, setHasAnthropicKey] = useState(false);
  const [ttsVoice, setTtsVoice] = useState("nova");
  const [ttsModel, setTtsModel] = useState("tts-1-hd");
  const [booksPerDay, setBooksPerDay] = useState(8);
  const [sourceDir, setSourceDir] = useState("");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    fetch("/api/settings")
      .then((r) => r.json())
      .then((data) => {
        setHasOpenaiKey(data.api_keys?.has_openai_key || false);
        setHasAnthropicKey(data.api_keys?.has_anthropic_key || false);
        if (data.settings) {
          setTtsVoice(data.settings.tts_voice || "nova");
          setTtsModel(data.settings.tts_model || "tts-1-hd");
          setBooksPerDay(data.settings.books_per_day || 8);
          setSourceDir(data.settings.book_source_dir || "");
        }
      });
  }, []);

  const save = async () => {
    setSaving(true);
    setMessage("");

    const body: Record<string, unknown> = {
      tts_voice: ttsVoice,
      tts_model: ttsModel,
      books_per_day: booksPerDay,
      book_source_dir: sourceDir || null,
    };

    // Only include keys if user typed something new
    if (openaiKey) body.openai_api_key = openaiKey;
    if (anthropicKey) body.anthropic_api_key = anthropicKey;

    const res = await fetch("/api/settings", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (res.ok) {
      setMessage("Settings saved.");
      if (openaiKey) {
        setHasOpenaiKey(true);
        setOpenaiKey("");
      }
      if (anthropicKey) {
        setHasAnthropicKey(true);
        setAnthropicKey("");
      }
      onUpdate();
    } else {
      setMessage("Failed to save settings.");
    }
    setSaving(false);
  };

  const removeKey = async (provider: "openai" | "anthropic") => {
    const body =
      provider === "openai"
        ? { openai_api_key: "" }
        : { anthropic_api_key: "" };
    await fetch("/api/settings", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (provider === "openai") setHasOpenaiKey(false);
    else setHasAnthropicKey(false);
    onUpdate();
  };

  return (
    <div className="p-4 pb-4 max-w-lg mx-auto">
      <h2 className="text-xl font-semibold mb-6">Settings</h2>

      {/* API Keys */}
      <section className="mb-8">
        <h3 className="text-sm font-medium text-secondary mb-3">API Keys</h3>
        <p className="text-xs text-muted mb-4">
          Your keys are stored locally and never shared. Required for audiobook
          generation and AI features.
        </p>

        {/* OpenAI */}
        <div className="mb-4">
          <label className="block text-xs font-medium text-secondary mb-1.5">
            OpenAI API Key{" "}
            {hasOpenaiKey && (
              <span className="text-emerald-600 dark:text-emerald-400">(configured)</span>
            )}
          </label>
          {hasOpenaiKey ? (
            <div className="flex items-center gap-2">
              <span className="text-xs text-muted">sk-...••••</span>
              <button
                onClick={() => removeKey("openai")}
                className="text-xs text-red-500 dark:text-red-400 hover:text-red-600 dark:hover:text-red-300"
              >
                Remove
              </button>
            </div>
          ) : (
            <input
              type="password"
              value={openaiKey}
              onChange={(e) => setOpenaiKey(e.target.value)}
              placeholder="sk-..."
              className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors font-mono"
            />
          )}
          <p className="text-xs text-muted mt-1">
            Used for TTS audiobook generation
          </p>
        </div>

        {/* Anthropic */}
        <div className="mb-4">
          <label className="block text-xs font-medium text-secondary mb-1.5">
            Anthropic API Key{" "}
            {hasAnthropicKey && (
              <span className="text-emerald-600 dark:text-emerald-400">(configured)</span>
            )}
          </label>
          {hasAnthropicKey ? (
            <div className="flex items-center gap-2">
              <span className="text-xs text-muted">sk-ant-...••••</span>
              <button
                onClick={() => removeKey("anthropic")}
                className="text-xs text-red-500 dark:text-red-400 hover:text-red-600 dark:hover:text-red-300"
              >
                Remove
              </button>
            </div>
          ) : (
            <input
              type="password"
              value={anthropicKey}
              onChange={(e) => setAnthropicKey(e.target.value)}
              placeholder="sk-ant-..."
              className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors font-mono"
            />
          )}
          <p className="text-xs text-muted mt-1">
            Reserved for future AI features
          </p>
        </div>
      </section>

      {/* TTS Settings */}
      <section className="mb-8">
        <h3 className="text-sm font-medium text-secondary mb-3">
          Audiobook Settings
        </h3>

        <div className="mb-4">
          <label className="block text-xs font-medium text-secondary mb-1.5">
            Voice
          </label>
          <select
            value={ttsVoice}
            onChange={(e) => setTtsVoice(e.target.value)}
            className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
          >
            <option value="nova">Nova (warm, natural)</option>
            <option value="alloy">Alloy (neutral)</option>
            <option value="echo">Echo (deep)</option>
            <option value="fable">Fable (expressive)</option>
            <option value="onyx">Onyx (authoritative)</option>
            <option value="shimmer">Shimmer (gentle)</option>
          </select>
        </div>

        <div className="mb-4">
          <label className="block text-xs font-medium text-secondary mb-1.5">
            Quality
          </label>
          <select
            value={ttsModel}
            onChange={(e) => setTtsModel(e.target.value)}
            className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
          >
            <option value="tts-1-hd">HD (higher quality, ~$0.03/1k chars)</option>
            <option value="tts-1">Standard (faster, ~$0.015/1k chars)</option>
          </select>
        </div>
      </section>

      {/* Generation Settings */}
      <section className="mb-8">
        <h3 className="text-sm font-medium text-secondary mb-3">
          Generation
        </h3>

        <div className="mb-4">
          <label className="block text-xs font-medium text-secondary mb-1.5">
            Books per day
          </label>
          <input
            type="number"
            min={1}
            max={20}
            value={booksPerDay}
            onChange={(e) => setBooksPerDay(parseInt(e.target.value) || 8)}
            className="w-20 px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
          />
        </div>

        <div className="mb-4">
          <label className="block text-xs font-medium text-secondary mb-1.5">
            Book source directory
          </label>
          <input
            type="text"
            value={sourceDir}
            onChange={(e) => setSourceDir(e.target.value)}
            placeholder="/Users/zwang/bookfactory"
            className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors font-mono"
          />
          <p className="text-xs text-muted mt-1">
            Where to scan for generated books
          </p>
        </div>
      </section>

      {/* Save */}
      {message && (
        <p className="text-xs text-emerald-600 dark:text-emerald-400 mb-3">{message}</p>
      )}
      <button
        onClick={save}
        disabled={saving}
        className="w-full py-2.5 bg-amber-600 text-white font-medium rounded-lg text-sm hover:bg-amber-700 transition-colors disabled:opacity-50"
      >
        {saving ? "Saving..." : "Save Settings"}
      </button>
    </div>
  );
}
