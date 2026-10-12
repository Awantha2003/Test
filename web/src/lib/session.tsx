"use client";

import { onIdTokenChanged, signOut, User } from "firebase/auth";
import { createContext, ReactNode, useContext, useEffect, useState } from "react";
import { auth } from "./firebase";

export interface Session {
  user: User;
  role: "parent" | "child" | null;
  familyId: string | null;
  isAdmin: boolean;
  /** True when the current sign-in used a second factor (required for admin actions). */
  mfa: boolean;
}

interface SessionState {
  loading: boolean;
  session: Session | null;
}

const Ctx = createContext<SessionState>({ loading: true, session: null });

export function SessionProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<SessionState>({ loading: true, session: null });
  useEffect(
    () =>
      onIdTokenChanged(auth, async (user) => {
        if (!user) return setState({ loading: false, session: null });
        const t = await user.getIdTokenResult();
        const c = t.claims as Record<string, unknown>;
        setState({
          loading: false,
          session: {
            user,
            role: (c.role as Session["role"]) ?? null,
            familyId: (c.familyId as string) ?? null,
            isAdmin: c.admin === true,
            mfa: Boolean((c.firebase as { sign_in_second_factor?: string } | undefined)?.sign_in_second_factor),
          },
        });
      }),
    [],
  );
  return <Ctx.Provider value={state}>{children}</Ctx.Provider>;
}

export const useSession = () => useContext(Ctx);
export const logout = () => signOut(auth);
