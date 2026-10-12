/**
 * Grant or revoke the admin role. An operator runs this offline with a service account:
 *   GOOGLE_APPLICATION_CREDENTIALS=sa.json npm run grant-admin -- admin@rakawala.lk [--revoke]
 * There is deliberately no API for this, so admin can never be granted from the app or the web.
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

async function main() {
  const [email, flag] = process.argv.slice(2);
  if (!email) throw new Error("Usage: grant-admin <email> [--revoke]");
  initializeApp({ credential: applicationDefault() });
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  const revoke = flag === "--revoke";
  if (!revoke && !user.multiFactor?.enrolledFactors.length) {
    console.warn("⚠  No second factor enrolled. This user can't use admin features until they enrol an authenticator app (TOTP).");
  }
  const claims = { ...(user.customClaims ?? {}) };
  if (revoke) delete claims.admin;
  else claims.admin = true;
  await auth.setCustomUserClaims(user.uid, claims);
  await auth.revokeRefreshTokens(user.uid); // force a fresh token with the new claims
  await getFirestore().collection("auditLogs").add({
    actorUid: null,
    action: revoke ? "admin.revoked" : "admin.granted",
    target: { uid: user.uid, email },
    createdAt: FieldValue.serverTimestamp(),
  });
  console.log(`${revoke ? "Revoked" : "Granted"} admin for ${email} (${user.uid}).`);
}

main().catch((e: Error) => {
  console.error(e.message);
  process.exit(1);
});
