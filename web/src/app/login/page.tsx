"use client";

import { GoogleAuthProvider, sendPasswordResetEmail, signInWithEmailAndPassword, signInWithPopup, getMultiFactorResolver, MultiFactorError, TotpMultiFactorGenerator } from "firebase/auth";
import { useRouter } from "next/navigation";
import { FormEvent, useEffect, useState } from "react";
import { Logo } from "@/components/Brand";
import { Notice } from "@/components/ui";
import { auth } from "@/lib/firebase";
import { useSession } from "@/lib/session";

function authError(code?: string) {
  switch (code) {
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
      return "Email or password is incorrect.";
    case "auth/too-many-requests":
      return "Too many attempts. Please wait a few minutes.";
    case "auth/user-disabled":
      return "This account is disabled. Contact support.";
    case "auth/invalid-verification-code":
      return "That code is incorrect.";
    default:
      return "Sign-in failed. Please try again.";
  }
}

export default function LoginPage() {
  const router = useRouter();
  const { session, loading } = useSession();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [mfa, setMfa] = useState<MultiFactorError | null>(null);
  const [otp, setOtp] = useState("");

  useEffect(() => {
    if (loading || !session) return;
    const next = new URLSearchParams(window.location.search).get("next");
    router.replace(session.isAdmin ? "/admin/" : next === "billing" ? "/dashboard/billing/" : "/dashboard/");
  }, [session, loading, router]);

  async function run(fn: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      const err = e as { code?: string };
      if (err.code === "auth/multi-factor-auth-required") setMfa(e as MultiFactorError);
      else if (err.code !== "auth/popup-closed-by-user") setError(authError(err.code));
    } finally {
      setBusy(false);
    }
  }

  const submit = (e: FormEvent) => {
    e.preventDefault();
    run(() => signInWithEmailAndPassword(auth, email.trim(), password));
  };

  const submitOtp = (e: FormEvent) => {
    e.preventDefault();
    if (!mfa) return;
    run(async () => {
      const resolver = getMultiFactorResolver(auth, mfa);
      const hint = resolver.hints.find((h) => h.factorId === TotpMultiFactorGenerator.FACTOR_ID);
      if (!hint) throw { code: "auth/unsupported-second-factor" };
      await resolver.resolveSignIn(TotpMultiFactorGenerator.assertionForSignIn(hint.uid, otp.trim()));
    });
  };

  const reset = async () => {
    if (!email) return setError("Enter your email first.");
    await sendPasswordResetEmail(auth, email.trim()).catch(() => undefined);
    setInfo("If an account exists, a reset link is on its way.");
  };

  return (
    <main className="grid min-h-screen md:grid-cols-2">
      <div className="hidden flex-col justify-between bg-gradient-to-br from-brand-900 to-brand-600 p-12 text-white md:flex">
        <Logo light />
        <div>
          <h1 className="text-4xl font-extrabold leading-tight">Know they&apos;re safe.<br />Every step of the way.</h1>
          <p className="mt-4 text-blue-100">See your family&apos;s live map, alerts and billing from any browser.</p>
        </div>
        <p className="text-sm text-blue-200">Emergency? Call 119.</p>
      </div>
      <div className="flex items-center justify-center p-6">
        <div className="w-full max-w-sm">
          <div className="md:hidden"><Logo /></div>
          <h2 className="mt-8 text-2xl font-extrabold">Sign in</h2>
          <p className="mt-1 text-sm text-slate-500">New? Create your account in the Rakawala app.</p>
          <div className="mt-6 space-y-3">
            {error && <Notice tone="error">{error}</Notice>}
            {info && <Notice tone="success">{info}</Notice>}
          </div>
          {mfa ? (
            <form onSubmit={submitOtp} className="mt-6 space-y-4">
              <label className="label" htmlFor="otp">Authenticator code</label>
              <input id="otp" className="input tracking-[0.4em]" inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={otp} onChange={(e) => setOtp(e.target.value)} />
              <button className="btn-primary w-full" disabled={busy || otp.length < 6}>Verify</button>
            </form>
          ) : (
            <>
              <form onSubmit={submit} className="mt-6 space-y-4">
                <div>
                  <label className="label" htmlFor="email">Email</label>
                  <input id="email" className="input" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
                </div>
                <div>
                  <label className="label" htmlFor="password">Password</label>
                  <input id="password" className="input" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
                </div>
                <button className="btn-primary w-full" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</button>
              </form>
              <button onClick={reset} className="mt-3 text-sm font-medium text-brand-600">Forgot password?</button>
              <div className="my-6 flex items-center gap-3 text-xs text-slate-400"><span className="h-px flex-1 bg-slate-200" />or<span className="h-px flex-1 bg-slate-200" /></div>
              <button className="btn-secondary w-full" disabled={busy} onClick={() => run(() => signInWithPopup(auth, new GoogleAuthProvider()))}>Continue with Google</button>
            </>
          )}
        </div>
      </div>
    </main>
  );
}
