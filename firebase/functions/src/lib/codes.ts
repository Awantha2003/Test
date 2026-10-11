/** Pairing / invite codes. Pure, no Firebase imports. */
import { createHash, randomInt } from "node:crypto";

// No 0/O, 1/I/L, so codes are easy to read aloud and type.
export const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const CODE_LENGTH = 8;
export const CODE_TTL_MS = 10 * 60 * 1000;

export function generateCode(): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) out += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return out;
}

/** "k7q2-m9xd " → "K7Q2M9XD". Returns null if it can't be a valid code. */
export function normalizeCode(input: string): string | null {
  const c = input.toUpperCase().replace(/[\s-]/g, "");
  if (c.length !== CODE_LENGTH) return null;
  for (const ch of c) if (!CODE_ALPHABET.includes(ch)) return null;
  return c;
}

export function formatCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

/** Codes are stored only as a hash so a database read never reveals a usable code. */
export function hashCode(code: string): string {
  return createHash("sha256").update(`rakawala:${code}`).digest("hex");
}
