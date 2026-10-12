import { db, FieldValue } from "./firebase";

export async function audit(
  actorUid: string | null,
  action: string,
  target: Record<string, unknown> = {},
): Promise<void> {
  await db.collection("auditLogs").add({
    actorUid,
    action,
    target,
    createdAt: FieldValue.serverTimestamp(),
  });
}
