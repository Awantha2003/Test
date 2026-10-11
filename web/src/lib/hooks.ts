"use client";

import {
  collection,
  doc,
  DocumentData,
  onSnapshot,
  query,
  Query,
  QueryConstraint,
} from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";

export type WithId<T> = T & { id: string };

interface Live<T> {
  data: T;
  loading: boolean;
  error: string | null;
}

/**
 * Real-time collection subscription. Pass `null` path to skip.
 * `depKey` must change whenever `constraints` change (constraints aren't comparable).
 */
export function useCollection<T = DocumentData>(path: string | null, constraints: QueryConstraint[] = [], depKey = ""): Live<WithId<T>[]> {
  const [state, setState] = useState<Live<WithId<T>[]>>({ data: [], loading: Boolean(path), error: null });
  const key = `${path}|${depKey}`;
  useEffect(() => {
    if (!path) return setState({ data: [], loading: false, error: null });
    const q: Query = query(collection(db, path), ...constraints);
    return onSnapshot(
      q,
      (s) => setState({ data: s.docs.map((d) => ({ id: d.id, ...(d.data() as T) })), loading: false, error: null }),
      (e) => setState({ data: [], loading: false, error: e.code === "permission-denied" ? "You don't have access to this." : "Couldn't load data." }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return state;
}

export function useDoc<T = DocumentData>(path: string | null): Live<WithId<T> | null> {
  const [state, setState] = useState<Live<WithId<T> | null>>({ data: null, loading: Boolean(path), error: null });
  useEffect(() => {
    if (!path) return setState({ data: null, loading: false, error: null });
    return onSnapshot(
      doc(db, path),
      (d) => setState({ data: d.exists() ? { id: d.id, ...(d.data() as T) } : null, loading: false, error: null }),
      () => setState({ data: null, loading: false, error: "Couldn't load data." }),
    );
  }, [path]);
  return state;
}
