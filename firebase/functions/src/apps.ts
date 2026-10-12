import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { familyRef } from "./lib/firebase";
import { raiseAlert } from "./lib/notify";
import { controlsTurnedOff, ControlsState, InstalledApp, newlyInstalled } from "./lib/apps";

/**
 * Watches the child phone's app report:
 *  - tells guardians if app controls were switched off on the phone (tamper),
 *  - tells guardians when a new app is installed.
 */
export const onAppUsage = onDocumentWritten({ document: "families/{fid}/appUsage/{cid}", retry: false }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return;
  const { fid, cid } = event.params;
  const child = await familyRef(fid).collection("children").doc(cid).get();
  if (!child.exists) return;
  const name = child.get("name") as string;

  if (controlsTurnedOff(before?.controls as ControlsState | undefined, after.controls as ControlsState | undefined)) {
    await raiseAlert(fid, {
      type: "apps",
      childId: cid,
      childName: name,
      title: `App controls were turned off on ${name}'s phone`,
      body: "Blocked apps and time limits won't work until they're turned back on in the phone's settings.",
    });
  }

  const added = newlyInstalled(before?.installed as InstalledApp[] | undefined, after.installed as InstalledApp[] | undefined);
  if (added.length > 0) {
    const names = added.slice(0, 3).map((a) => a.name || a.pkg).join(", ");
    await raiseAlert(fid, {
      type: "apps",
      childId: cid,
      childName: name,
      title: `${name} installed ${added.length === 1 ? "a new app" : `${added.length} new apps`}`,
      body: `${names}${added.length > 3 ? " and more" : ""}. You can allow, limit or block it in App controls.`,
    });
  }
});
