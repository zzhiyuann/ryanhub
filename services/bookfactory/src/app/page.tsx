"use client";

import { useAuth } from "@/lib/hooks";
import { LoginPage } from "@/components/login";
import { AppShell } from "@/components/app-shell";

export default function Home() {
  const auth = useAuth();

  if (auth.loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-pulse text-zinc-500 text-lg">Loading...</div>
      </div>
    );
  }

  if (!auth.user) {
    return <LoginPage onLogin={auth.login} onRegister={auth.register} />;
  }

  return <AppShell user={auth.user} onLogout={auth.logout} onRefreshAuth={auth.refresh} />;
}
