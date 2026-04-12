import admin from "firebase-admin";
import type { UserDoc, CatchUpDoc, CallDoc } from "../types/index.js";

/**
 * Convenience reference to the Firestore instance.
 * firebase-admin must be initialized before these helpers are called
 * (done in src/index.ts at startup).
 */
function db(): admin.firestore.Firestore {
  return admin.firestore();
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

/**
 * Fetch a user document by ID.
 * Returns null if the document does not exist.
 */
export async function getUser(userId: string): Promise<UserDoc | null> {
  const doc = await db().collection("users").doc(userId).get();
  if (!doc.exists) return null;
  return doc.data() as UserDoc;
}

/**
 * Update (merge) fields on a user document.
 */
export async function updateUser(
  userId: string,
  data: Partial<UserDoc>,
): Promise<void> {
  await db().collection("users").doc(userId).set(data, { merge: true });
}

// ---------------------------------------------------------------------------
// Catch-Ups
// ---------------------------------------------------------------------------

/**
 * Fetch a single catch-up document by ID.
 * Returns null if the document does not exist.
 */
export async function getCatchUp(catchupId: string): Promise<(CatchUpDoc & { id: string }) | null> {
  const doc = await db().collection("catchups").doc(catchupId).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...(doc.data() as CatchUpDoc) };
}

/**
 * Get all active catch-ups where the given user is either userA or userB.
 *
 * Firestore does not support OR queries across different fields in a single
 * query, so we run two queries in parallel and merge the results.
 */
export async function getVisibleCatchUpsForUser(
  userId: string,
): Promise<(CatchUpDoc & { id: string })[]> {
  const [activeA, activeB, pendingA] = await Promise.all([
    db()
      .collection("catchups")
      .where("userA", "==", userId)
      .where("status", "==", "active")
      .get(),
    db()
      .collection("catchups")
      .where("userB", "==", userId)
      .where("status", "==", "active")
      .get(),
    db()
      .collection("catchups")
      .where("userA", "==", userId)
      .where("status", "==", "pending")
      .get(),
  ]);

  const results: (CatchUpDoc & { id: string })[] = [];

  for (const doc of activeA.docs) {
    results.push({ id: doc.id, ...(doc.data() as CatchUpDoc) });
  }
  for (const doc of activeB.docs) {
    results.push({ id: doc.id, ...(doc.data() as CatchUpDoc) });
  }
  for (const doc of pendingA.docs) {
    results.push({ id: doc.id, ...(doc.data() as CatchUpDoc) });
  }

  // Deduplicate (shouldn't happen, but be safe).
  const seen = new Set<string>();
  return results.filter((r) => {
    if (seen.has(r.id)) return false;
    seen.add(r.id);
    return true;
  });
}

/**
 * Update (merge) fields on a catch-up document.
 */
export async function updateCatchUp(
  catchupId: string,
  data: Partial<CatchUpDoc>,
): Promise<void> {
  await db().collection("catchups").doc(catchupId).set(data, { merge: true });
}

// ---------------------------------------------------------------------------
// Calls
// ---------------------------------------------------------------------------

/**
 * Create a new call document. Returns the auto-generated document ID.
 */
export async function createCall(data: CallDoc): Promise<string> {
  const docRef = await db().collection("calls").add(data);
  return docRef.id;
}

/**
 * Fetch a single call document by ID.
 * Returns null if the document does not exist.
 */
export async function getCall(callId: string): Promise<(CallDoc & { id: string }) | null> {
  const doc = await db().collection("calls").doc(callId).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...(doc.data() as CallDoc) };
}

/**
 * Update (merge) fields on a call document.
 */
export async function updateCall(
  callId: string,
  data: Partial<CallDoc>,
): Promise<void> {
  await db().collection("calls").doc(callId).set(data, { merge: true });
}
