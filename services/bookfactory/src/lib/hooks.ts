"use client";

import { useState, useEffect, useCallback } from "react";

// Auth hook
export function useAuth() {
  const [user, setUser] = useState<{
    id: string;
    username: string;
    display_name: string;
    has_openai_key: boolean;
    has_anthropic_key: boolean;
  } | null>(null);
  const [loading, setLoading] = useState(true);

  const checkAuth = useCallback(async () => {
    try {
      const res = await fetch("/api/auth/me");
      if (res.ok) {
        const data = await res.json();
        setUser(data.user);
      } else {
        setUser(null);
      }
    } catch {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  const login = async (username: string, password: string) => {
    const res = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password }),
    });
    if (!res.ok) {
      const data = await res.json();
      throw new Error(data.error);
    }
    await checkAuth();
  };

  const register = async (
    username: string,
    password: string,
    displayName: string
  ) => {
    const res = await fetch("/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password, display_name: displayName }),
    });
    if (!res.ok) {
      const data = await res.json();
      throw new Error(data.error);
    }
    await checkAuth();
  };

  const logout = async () => {
    await fetch("/api/auth/logout", { method: "POST" });
    setUser(null);
  };

  return { user, loading, login, register, logout, refresh: checkAuth };
}

// Books hook
export function useBooks() {
  const [books, setBooks] = useState<Book[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchBooks = useCallback(async () => {
    try {
      const res = await fetch("/api/books");
      if (res.ok) {
        const data = await res.json();
        setBooks(data.books);
      }
    } catch (e) {
      console.error("Failed to fetch books:", e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchBooks();
  }, [fetchBooks]);

  const scanBooks = async (sourceDir?: string) => {
    const res = await fetch("/api/books/scan", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ source_dir: sourceDir }),
    });
    const data = await res.json();
    await fetchBooks();
    return data;
  };

  return { books, loading, refresh: fetchBooks, scanBooks };
}

export interface Book {
  id: string;
  user_id: string;
  title: string;
  topic: string | null;
  date: string;
  slot: string | null;
  word_count: number;
  language: string;
  md_path: string | null;
  html_path: string | null;
  has_audio: number;
  audio_duration: number | null;
  audio_voice: string | null;
  created_at: string;
}
