import { setGlobalOptions } from "firebase-functions/v2";

// Mumbai is the closest Google Cloud region to Sri Lanka.
setGlobalOptions({ region: "asia-south1", maxInstances: 20, memory: "256MiB" });

export { createFamily, savePlace, deletePlace, saveSchedule, deleteSchedule, deleteMyAccount, getUsage } from "./family";
export { createPairingCode, redeemPairingCode, redeemGuardianInvite, removeChild, removeGuardian } from "./pairing";
export { onLiveLocation } from "./location";
export { triggerSos, checkIn, resolveAlert } from "./sos";
export { checkSchedules, checkHeartbeats, expireSubscriptions } from "./jobs";
export { createCheckout, payhereNotify } from "./billing";
export { adminStats, adminSetUserDisabled, adminSetFamilyPlan, adminSeed, auditPlans, auditSiteContent } from "./admin";
