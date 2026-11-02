import { useState, type FormEvent } from "react";
import { authErrorMessage, logIn } from "./auth";
import { Button, ErrorNote, TextInput } from "./ui";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!email.trim() || !password) {
      setError("Enter both your email and password.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await logIn(email, password);
    } catch (err) {
      setError(authErrorMessage(err));
      setBusy(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-sm">
        <a href="/" className="mb-8 flex items-center justify-center gap-2.5" aria-label="Back to the Allim site">
          <img src="/allim-icon.svg" alt="" width="40" height="40" className="h-10 w-10 rounded-[9px]" />
          <span className="text-[26px] font-extrabold tracking-[-0.03em] text-ink">Allim</span>
        </a>

        <form onSubmit={submit} className="rounded-3xl border border-line bg-card p-6 shadow-[0_18px_40px_-24px_rgba(22,25,28,0.35)]">
          <h1 className="display text-[26px] text-ink">Welcome back</h1>
          <p className="mt-1 text-[15px] text-ink-2">Sign in with the account you use in the app.</p>

          <label className="mt-6 block text-[13px] font-semibold text-ink-2" htmlFor="email">
            Email
          </label>
          <TextInput
            id="email"
            type="email"
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            className="mt-1.5"
            autoFocus
          />

          <label className="mt-4 block text-[13px] font-semibold text-ink-2" htmlFor="password">
            Password
          </label>
          <TextInput
            id="password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1.5"
          />

          {error && <div className="mt-4"><ErrorNote>{error}</ErrorNote></div>}

          <Button type="submit" disabled={busy} className="mt-6 w-full py-3 text-[15px]">
            {busy ? "Signing in…" : "Sign in"}
          </Button>
        </form>

        <p className="mt-5 text-center text-[13px] text-ink-3">
          Development build · connected to the live Allim database
        </p>
      </div>
    </div>
  );
}
