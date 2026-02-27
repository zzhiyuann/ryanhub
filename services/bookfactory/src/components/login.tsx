"use client";

import { useState } from "react";

interface LoginPageProps {
  onLogin: (username: string, password: string) => Promise<void>;
  onRegister: (
    username: string,
    password: string,
    displayName: string
  ) => Promise<void>;
}

export function LoginPage({ onLogin, onRegister }: LoginPageProps) {
  const [isRegister, setIsRegister] = useState(false);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (isRegister) {
        await onRegister(username, password, displayName || username);
      } else {
        await onLogin(username, password);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold tracking-tight">Book Factory</h1>
          <p className="text-muted mt-2 text-sm">
            Personal book generation & audiobook platform
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-secondary mb-1.5">
              Username
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
              autoFocus
              required
            />
          </div>

          {isRegister && (
            <div>
              <label className="block text-xs font-medium text-secondary mb-1.5">
                Display Name
              </label>
              <input
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Optional"
                className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
              />
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-secondary mb-1.5">
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 bg-input border border-default rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/30 focus:border-amber-500/50 transition-colors"
              required
            />
          </div>

          {error && (
            <p className="text-red-600 dark:text-red-400 text-xs bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900/50 rounded-lg px-3 py-2">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 bg-amber-600 text-white font-medium rounded-lg text-sm hover:bg-amber-700 transition-colors disabled:opacity-50"
          >
            {loading
              ? "..."
              : isRegister
                ? "Create Account"
                : "Sign In"}
          </button>
        </form>

        <p className="text-center text-xs text-muted mt-4">
          {isRegister ? "Already have an account?" : "No account yet?"}{" "}
          <button
            onClick={() => {
              setIsRegister(!isRegister);
              setError("");
            }}
            className="text-secondary hover:text-primary transition-colors"
          >
            {isRegister ? "Sign in" : "Register"}
          </button>
        </p>
      </div>
    </div>
  );
}
