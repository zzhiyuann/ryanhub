"use client";

import { useState, useEffect, useCallback } from "react";

interface Topic {
  id: string;
  tier: string | null;
  title: string;
  description: string | null;
  status: string;
  position: number;
  generated_date: string | null;
  generated_slot: string | null;
}

export function QueueManager() {
  const [topics, setTopics] = useState<Topic[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "pending" | "done" | "skipped">(
    "all"
  );
  const [showAdd, setShowAdd] = useState(false);
  const [newTitle, setNewTitle] = useState("");
  const [newTier, setNewTier] = useState("");
  const [newDesc, setNewDesc] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [syncing, setSyncing] = useState(false);

  const fetchTopics = useCallback(async () => {
    try {
      const res = await fetch("/api/queue");
      if (res.ok) {
        const data = await res.json();
        setTopics(data.topics);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTopics();
  }, [fetchTopics]);

  const syncBacklog = async () => {
    setSyncing(true);
    try {
      const res = await fetch("/api/queue/sync", { method: "POST" });
      if (res.ok) {
        const data = await res.json();
        alert(`Synced: ${data.added} added, ${data.updated} updated, ${data.total} total`);
        fetchTopics();
      } else {
        const data = await res.json();
        alert(data.error || "Sync failed");
      }
    } catch {
      alert("Sync failed");
    } finally {
      setSyncing(false);
    }
  };

  const addTopic = async () => {
    if (!newTitle.trim()) return;
    await fetch("/api/queue/topics", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: newTitle,
        tier: newTier || null,
        description: newDesc || null,
      }),
    });
    setNewTitle("");
    setNewTier("");
    setNewDesc("");
    setShowAdd(false);
    fetchTopics();
  };

  const deleteTopic = async (id: string) => {
    if (!confirm("Delete this topic?")) return;
    await fetch(`/api/queue/topics/${id}`, { method: "DELETE" });
    fetchTopics();
  };

  const updateStatus = async (id: string, status: string) => {
    await fetch(`/api/queue/topics/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status }),
    });
    fetchTopics();
  };

  const saveEdit = async (id: string) => {
    await fetch(`/api/queue/topics/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: editTitle }),
    });
    setEditingId(null);
    fetchTopics();
  };

  const moveUp = async (index: number) => {
    if (index === 0) return;
    const ids = filteredTopics.map((t) => t.id);
    [ids[index - 1], ids[index]] = [ids[index], ids[index - 1]];
    await fetch("/api/queue/reorder", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ topicIds: ids }),
    });
    fetchTopics();
  };

  const moveDown = async (index: number) => {
    if (index >= filteredTopics.length - 1) return;
    const ids = filteredTopics.map((t) => t.id);
    [ids[index], ids[index + 1]] = [ids[index + 1], ids[index]];
    await fetch("/api/queue/reorder", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ topicIds: ids }),
    });
    fetchTopics();
  };

  const filteredTopics = topics.filter(
    (t) => filter === "all" || t.status === filter
  );

  const statusColors: Record<string, string> = {
    pending: "text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950/50",
    done: "text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/50",
    skipped: "text-muted bg-secondary",
  };

  const stats = {
    total: topics.length,
    pending: topics.filter((t) => t.status === "pending").length,
    done: topics.filter((t) => t.status === "done").length,
    skipped: topics.filter((t) => t.status === "skipped").length,
  };

  if (loading) {
    return (
      <div className="p-6 text-center text-muted">Loading queue...</div>
    );
  }

  return (
    <div className="p-4 pb-4 max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold">Generation Queue</h2>
        <div className="flex gap-2">
          <button
            onClick={syncBacklog}
            disabled={syncing}
            className="text-xs px-3 py-1.5 bg-secondary hover:bg-tertiary rounded-lg transition-colors disabled:opacity-50"
          >
            {syncing ? "Syncing..." : "Sync Backlog"}
          </button>
          <button
            onClick={() => setShowAdd(!showAdd)}
            className="text-xs px-3 py-1.5 bg-secondary hover:bg-tertiary rounded-lg transition-colors"
          >
            + Add Topic
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="flex gap-3 mb-4 text-xs">
        <span className="text-muted">
          {stats.total} total
        </span>
        <span className="text-blue-600 dark:text-blue-400">{stats.pending} pending</span>
        <span className="text-emerald-600 dark:text-emerald-400">{stats.done} done</span>
        <span className="text-muted">{stats.skipped} skipped</span>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-1 mb-4">
        {(["all", "pending", "done", "skipped"] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-3 py-1 text-xs rounded-lg transition-colors capitalize ${
              filter === f
                ? "bg-secondary text-primary"
                : "text-muted hover:text-secondary"
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      {/* Add topic form */}
      {showAdd && (
        <div className="mb-4 p-4 bg-card border border-default rounded-xl space-y-3">
          <input
            type="text"
            placeholder="Topic title"
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
            autoFocus
          />
          <div className="flex gap-2">
            <input
              type="text"
              placeholder="Tier (optional)"
              value={newTier}
              onChange={(e) => setNewTier(e.target.value)}
              className="flex-1 px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
            />
          </div>
          <textarea
            placeholder="Description / notes (optional)"
            value={newDesc}
            onChange={(e) => setNewDesc(e.target.value)}
            className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors h-20 resize-none"
          />
          <div className="flex gap-2">
            <button
              onClick={addTopic}
              className="px-4 py-2 bg-amber-600 text-white text-xs font-medium rounded-lg hover:bg-amber-700 transition-colors"
            >
              Add
            </button>
            <button
              onClick={() => setShowAdd(false)}
              className="px-4 py-2 text-xs text-muted hover:text-secondary transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Topic list */}
      <div className="space-y-1">
        {filteredTopics.map((topic, index) => (
          <div
            key={topic.id}
            className="flex items-center gap-2 p-3 bg-card hover:bg-card-hover rounded-lg transition-colors group"
          >
            {/* Reorder buttons */}
            <div className="flex flex-col gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
              <button
                onClick={() => moveUp(index)}
                className="text-muted hover:text-primary text-xs leading-none"
              >
                ▲
              </button>
              <button
                onClick={() => moveDown(index)}
                className="text-muted hover:text-primary text-xs leading-none"
              >
                ▼
              </button>
            </div>

            {/* Content */}
            <div className="flex-1 min-w-0">
              {editingId === topic.id ? (
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={editTitle}
                    onChange={(e) => setEditTitle(e.target.value)}
                    className="flex-1 px-2 py-1 bg-input border border-default rounded text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30"
                    onKeyDown={(e) => {
                      if (e.key === "Enter") saveEdit(topic.id);
                      if (e.key === "Escape") setEditingId(null);
                    }}
                    autoFocus
                  />
                  <button
                    onClick={() => saveEdit(topic.id)}
                    className="text-xs text-emerald-600 dark:text-emerald-400"
                  >
                    Save
                  </button>
                </div>
              ) : (
                <div
                  className="cursor-pointer"
                  onDoubleClick={() => {
                    setEditingId(topic.id);
                    setEditTitle(topic.title);
                  }}
                >
                  <span className="text-sm">{topic.title}</span>
                  {topic.tier && (
                    <span className="ml-2 text-xs text-muted">
                      [{topic.tier}]
                    </span>
                  )}
                  {topic.generated_date && (
                    <span className="ml-2 text-xs text-muted">
                      {topic.generated_date}
                    </span>
                  )}
                </div>
              )}
            </div>

            {/* Status badge */}
            <span
              className={`px-2 py-0.5 rounded text-xs ${statusColors[topic.status] || "text-muted"}`}
            >
              {topic.status}
            </span>

            {/* Actions */}
            <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              {topic.status === "pending" && (
                <button
                  onClick={() => updateStatus(topic.id, "skipped")}
                  className="text-xs text-muted hover:text-primary"
                  title="Skip"
                >
                  ⊘
                </button>
              )}
              {topic.status === "skipped" && (
                <button
                  onClick={() => updateStatus(topic.id, "pending")}
                  className="text-xs text-muted hover:text-primary"
                  title="Re-enable"
                >
                  ↺
                </button>
              )}
              <button
                onClick={() => deleteTopic(topic.id)}
                className="text-xs text-muted hover:text-red-500"
                title="Delete"
              >
                ✕
              </button>
            </div>
          </div>
        ))}
      </div>

      {filteredTopics.length === 0 && (
        <div className="text-center py-12 text-muted text-sm">
          {filter === "all"
            ? "No topics in the queue. Click \"Sync Backlog\" to import from topic_backlog.md."
            : `No ${filter} topics.`}
        </div>
      )}
    </div>
  );
}
