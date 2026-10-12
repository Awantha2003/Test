import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { familyRef } from "./lib/firebase";
import { raiseAlert } from "./lib/notify";
import { DeviceStatus, tamperEvents } from "./lib/device";

/** Tells guardians when protection on the child's phone is weakened (location, uninstall guard). */
export const onDeviceStatus = onDocumentWritten({ document: "families/{fid}/deviceStatus/{cid}", retry: false }, async (event) => {
  const events = tamperEvents(event.data?.before.data() as DeviceStatus | undefined, event.data?.after.data() as DeviceStatus | undefined);
  if (events.length === 0) return;
  const { fid, cid } = event.params;
  const child = await familyRef(fid).collection("children").doc(cid).get();
  if (!child.exists) return;
  const name = child.get("name") as string;
  for (const e of events) {
    await raiseAlert(fid, { type: "device", childId: cid, childName: name, title: e.title(name), body: e.body });
  }
});
