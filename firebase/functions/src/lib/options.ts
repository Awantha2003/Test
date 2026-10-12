import type { CallableOptions } from "firebase-functions/v2/https";

/**
 * App Check is enforced on every callable in production. For local emulator runs set
 * ENFORCE_APP_CHECK=false in functions/.env.local (never in .env or .env.<project>).
 */
export const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK !== "false";

export const callable = (extra: Partial<CallableOptions> = {}): CallableOptions => ({
  enforceAppCheck: ENFORCE_APP_CHECK,
  cors: false,
  ...extra,
});
