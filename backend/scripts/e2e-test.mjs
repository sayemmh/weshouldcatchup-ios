// End-to-end backend test for We Should Catch Up.
//
// Drives the real HTTP API through the full lifecycle — invite → accept → queue →
// call → AUTO-CAUGHT-UP → rotation-skip → re-catch request/accept → re-activate —
// asserting both HTTP responses and Firestore state at each step. Also proves the
// pre-feature upgrade path (callCount>0 with no `caughtUp` field is treated as caught up).
//
// What it CANNOT test (device-only): live APNs/FCM delivery and Agora audio media.
// Those are the residual covered by the 2-device manual test.
//
// Usage (from backend/):
//   node scripts/e2e-test.mjs
//   BASE_URL=https://<cloud-run-url> node scripts/e2e-test.mjs
//
// Requires: service-account.json (same one the backend uses) and a Firebase web API
// key (FIREBASE_API_KEY env, or the default below read from GoogleService-Info.plist).

import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import admin from "firebase-admin";

const __dirname = dirname(fileURLToPath(import.meta.url));
const BASE_URL = process.env.BASE_URL || "http://localhost:8080";
const API_KEY = process.env.FIREBASE_API_KEY || "AIzaSyCGSloJfk854U-K6liNPaZv2Cr3upq5b54";

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

const serviceAccountPath = resolve(__dirname, "..", "service-account.json");
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});
const db = admin.firestore();

const stamp = Date.now();
const A = `e2e-A-${stamp}`;
const B = `e2e-B-${stamp}`;
const C = `e2e-C-${stamp}`; // third user for the upgrade-path check

let passed = 0;
let failed = 0;
const created = { catchups: new Set(), calls: new Set(), users: new Set([A, B, C]) };

function ok(cond, msg) {
  if (cond) {
    passed++;
    console.log(`  ✓ ${msg}`);
  } else {
    failed++;
    console.error(`  ✗ ${msg}`);
  }
}

async function idTokenFor(uid) {
  const customToken = await admin.auth().createCustomToken(uid);
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const json = await res.json();
  if (!json.idToken) throw new Error(`Failed to mint ID token for ${uid}: ${JSON.stringify(json)}`);
  return json.idToken;
}

async function api(method, path, token, body) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* some endpoints may return empty */
  }
  return { status: res.status, json };
}

async function getCatchupDoc(id) {
  const snap = await db.collection("catchups").doc(id).get();
  return snap.exists ? snap.data() : null;
}

async function callCountForCatchup(catchupId) {
  const snap = await db.collection("calls").where("catchupId", "==", catchupId).get();
  return snap.size;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------
// The test
// ---------------------------------------------------------------------------

async function run() {
  console.log(`\nE2E against ${BASE_URL}\n`);

  // Health
  const health = await fetch(`${BASE_URL}/health`).then((r) => r.json()).catch(() => null);
  ok(health?.status === "ok", "GET /health is ok");

  const tokenA = await idTokenFor(A);
  const tokenB = await idTokenFor(B);

  // 1. Profiles
  console.log("\n[1] Profiles");
  ok((await api("POST", "/update-profile", tokenA, { displayName: "Alice E2E" })).status === 200, "A update-profile");
  ok((await api("POST", "/update-profile", tokenB, { displayName: "Bob E2E" })).status === 200, "B update-profile");

  // 2. Create + accept catch-up
  console.log("\n[2] Invite -> accept");
  const create = await api("POST", "/create-catchup", tokenA, { invitedName: "Bob" });
  ok(create.status === 200 && !!create.json.catchupId, "A create-catchup returns catchupId");
  const catchupId = create.json.catchupId;
  created.catchups.add(catchupId);

  const accept = await api("POST", "/accept-catchup", tokenB, { catchupId });
  ok(accept.status === 200 && accept.json.status === "active", "B accept-catchup -> active");
  let doc = await getCatchupDoc(catchupId);
  ok(doc?.status === "active" && doc?.callCount === 0 && doc?.caughtUp === false, "doc active, callCount 0, not caught up");

  // 3. Active queue shows B; caught-up empty
  console.log("\n[3] Queue before any call");
  let queueA = await api("GET", "/my-queue", tokenA);
  ok(queueA.json.some((i) => i.otherUser.userId === B), "A /my-queue includes B");
  let caughtA = await api("GET", "/caught-up", tokenA);
  ok(Array.isArray(caughtA.json) && caughtA.json.length === 0, "A /caught-up is empty");

  // 4. Call lifecycle (the rotation pre-creates the call doc + pushes; push/Agora are
  //    device-only, so here we create the call doc directly as the engine would, then
  //    exercise the real accept-ping/join-call/end-call endpoints).
  console.log("\n[4] Call lifecycle -> auto caught up");
  const callRef = await db.collection("calls").add({
    catchupId,
    participants: [A, B],
    agoraChannel: `catchup_${catchupId}_${stamp}`,
    startedAt: new Date().toISOString(),
    endedAt: null,
    duration: null,
  });
  const callId = callRef.id;
  created.calls.add(callId);

  const acceptPing = await api("POST", "/accept-ping", tokenB, { catchupId, callId });
  ok(acceptPing.status === 200 && !!acceptPing.json.agoraToken, "B accept-ping returns Agora token");
  const joinCall = await api("POST", "/join-call", tokenA, { callId });
  ok(joinCall.status === 200 && !!joinCall.json.agoraToken, "A join-call returns Agora token");
  const endCall = await api("POST", "/end-call", tokenA, { callId });
  ok(endCall.status === 200 && typeof endCall.json.duration === "number", "A end-call returns duration");

  doc = await getCatchupDoc(catchupId);
  ok(doc?.callCount === 1, "doc callCount == 1");
  ok(doc?.caughtUp === true, "doc caughtUp == true (auto-archived)");
  const [uA, uB] = await Promise.all([db.collection("users").doc(A).get(), db.collection("users").doc(B).get()]);
  ok(uA.data()?.status === "idle" && uB.data()?.status === "idle", "both users back to idle");

  // 5. Caught up moved lists
  console.log("\n[5] Lists after catching up");
  queueA = await api("GET", "/my-queue", tokenA);
  ok(!queueA.json.some((i) => i.otherUser.userId === B), "A /my-queue NO LONGER includes B");
  caughtA = await api("GET", "/caught-up", tokenA);
  ok(caughtA.json.some((i) => i.otherUser.userId === B && i.state === "idle"), "A /caught-up includes B (state idle)");

  // 6. Rotation actually skips caught-up people (not just the queue view).
  //    Give B a token so the ONLY reason rotation could skip is caughtUp.
  console.log("\n[6] Rotation skips caught-up");
  await db.collection("users").doc(B).set({ fcmToken: "e2e-dummy-token" }, { merge: true });
  const callsBefore = await callCountForCatchup(catchupId);
  ok((await api("POST", "/go-live", tokenA)).status === 200, "A go-live");
  await sleep(3000);
  const me = await api("GET", "/me", tokenA);
  ok(me.json.status === "live", "A /me status live");
  const callsAfter = await callCountForCatchup(catchupId);
  ok(callsAfter === callsBefore, "no new call doc created (rotation skipped caught-up B)");
  ok((await api("POST", "/cancel-live", tokenA)).status === 200, "A cancel-live");

  // 7. Re-catch request
  console.log("\n[7] Catch up again -> request");
  const selfAccept = await api("POST", "/accept-recatch", tokenA, { catchupId });
  ok(selfAccept.status === 409, "accept-recatch with no request -> 409");
  const reqRecatch = await api("POST", "/request-recatch", tokenA, { catchupId });
  ok(reqRecatch.status === 200, "A request-recatch");
  doc = await getCatchupDoc(catchupId);
  ok(doc?.recatchRequestedBy === A, "doc recatchRequestedBy == A");
  const cannotAcceptOwn = await api("POST", "/accept-recatch", tokenA, { catchupId });
  ok(cannotAcceptOwn.status === 409, "A cannot accept own request -> 409");
  caughtA = await api("GET", "/caught-up", tokenA);
  ok(caughtA.json.find((i) => i.otherUser.userId === B)?.state === "requested_by_me", "A sees state requested_by_me");
  const caughtB = await api("GET", "/caught-up", tokenB);
  ok(caughtB.json.find((i) => i.otherUser.userId === A)?.state === "incoming", "B sees state incoming");

  // 8. Re-catch accept -> reactivated
  console.log("\n[8] Accept -> reactivated");
  const acceptRecatch = await api("POST", "/accept-recatch", tokenB, { catchupId });
  ok(acceptRecatch.status === 200, "B accept-recatch");
  doc = await getCatchupDoc(catchupId);
  ok(doc?.caughtUp === false && !doc?.recatchRequestedBy, "doc caughtUp false, request cleared");
  queueA = await api("GET", "/my-queue", tokenA);
  ok(queueA.json.some((i) => i.otherUser.userId === B), "A /my-queue includes B again (re-activated)");

  // 9. Upgrade path: legacy doc with callCount>0 and NO caughtUp field is treated caught up.
  console.log("\n[9] Upgrade path (no caughtUp field)");
  await db.collection("users").doc(C).set({
    phone: "", displayName: "Carol E2E", fcmToken: null, status: "idle",
    liveSince: null, liveTTL: null, queueOrder: null,
    createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
  });
  const legacyRef = await db.collection("catchups").add({
    userA: A, userB: C, status: "active", invitedName: null,
    createdAt: new Date().toISOString(), acceptedAt: new Date().toISOString(),
    removedBy: null, lastCallAt: new Date().toISOString(), callCount: 1,
    // NOTE: no `caughtUp` field on purpose.
  });
  created.catchups.add(legacyRef.id);
  queueA = await api("GET", "/my-queue", tokenA);
  ok(!queueA.json.some((i) => i.otherUser.userId === C), "legacy pair excluded from /my-queue");
  caughtA = await api("GET", "/caught-up", tokenA);
  ok(caughtA.json.some((i) => i.otherUser.userId === C), "legacy pair present in /caught-up");
}

async function teardown() {
  console.log("\n[teardown]");
  for (const id of created.calls) await db.collection("calls").doc(id).delete().catch(() => {});
  for (const id of created.catchups) await db.collection("catchups").doc(id).delete().catch(() => {});
  for (const uid of created.users) {
    await db.collection("users").doc(uid).delete().catch(() => {});
    await admin.auth().deleteUser(uid).catch(() => {});
  }
  console.log("  cleaned up test users + docs");
}

try {
  await run();
} catch (err) {
  failed++;
  console.error("\nFATAL:", err);
} finally {
  await teardown().catch((e) => console.error("teardown error:", e));
}

console.log(`\n${"=".repeat(40)}\nRESULT: ${passed} passed, ${failed} failed\n${"=".repeat(40)}`);
process.exit(failed === 0 ? 0 : 1);
