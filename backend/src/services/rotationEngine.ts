import {
  getUser,
  updateUser,
  getActiveCatchUpsForUser,
  createCall,
} from "./firestoreService.js";
import { sendCatchUpPing } from "./pushService.js";
import { generateAgoraToken } from "./agoraTokenService.js";
import type { CatchUpDoc } from "../types/index.js";

// ---------------------------------------------------------------------------
// In-memory rotation state
// ---------------------------------------------------------------------------

interface RotationState {
  /** Set to true when cancelRotation() is called. The loop checks this flag. */
  cancelled: boolean;
  /** The timeout handle for the current 60-second wait so we can clear it. */
  currentTimeout: ReturnType<typeof setTimeout> | null;
  /** Resolves the current 60-second wait promise so we can break out early. */
  resolveWait: (() => void) | null;
}

/**
 * Map of userId -> RotationState.
 * Stored in memory because rotation is a transient, server-side process.
 * If the server restarts, live users will eventually time out via liveTTL.
 */
const activeRotations = new Map<string, RotationState>();

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Start the rotation engine for a user who just went live.
 *
 * High-level flow:
 *   1. Fetch the user's active catch-ups sorted by priority.
 *   2. First pass: check if anyone in the queue is already "live" -- if so,
 *      connect them immediately (mutual availability).
 *   3. Second pass: for each remaining person, send a push notification ping
 *      and wait up to 60 seconds for them to accept.
 *   4. If no one accepts and the liveTTL has not expired, keep the user "live".
 *   5. When liveTTL expires, set the user back to "idle".
 */
export async function startRotation(userId: string): Promise<void> {
  // Cancel any previous rotation for this user (shouldn't happen, but be safe).
  cancelRotation(userId);

  const state: RotationState = {
    cancelled: false,
    currentTimeout: null,
    resolveWait: null,
  };
  activeRotations.set(userId, state);

  try {
    await runRotationLoop(userId, state);
  } finally {
    activeRotations.delete(userId);
  }
}

/**
 * Cancel an in-progress rotation for the given user.
 * Called when the user taps "Cancel Live" or when a call is established.
 */
export function cancelRotation(userId: string): void {
  const state = activeRotations.get(userId);
  if (!state) return;

  state.cancelled = true;

  // If we're in the middle of a 60-second wait, resolve it immediately.
  if (state.resolveWait) {
    state.resolveWait();
  }
  if (state.currentTimeout) {
    clearTimeout(state.currentTimeout);
  }

  activeRotations.delete(userId);
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Sort catch-ups by rotation priority:
 *   - lastCallAt === null first (never called).
 *   - Among nulls, newest catch-up first (createdAt desc).
 *   - Among non-nulls, oldest call first (lastCallAt asc).
 */
function sortByPriority(catchups: (CatchUpDoc & { id: string })[]): (CatchUpDoc & { id: string })[] {
  return [...catchups].sort((a, b) => {
    if (a.lastCallAt === null && b.lastCallAt !== null) return -1;
    if (a.lastCallAt !== null && b.lastCallAt === null) return 1;
    if (a.lastCallAt === null && b.lastCallAt === null) {
      return b.createdAt.localeCompare(a.createdAt);
    }
    return a.lastCallAt!.localeCompare(b.lastCallAt!);
  });
}

/**
 * The main rotation loop.
 */
async function runRotationLoop(userId: string, state: RotationState): Promise<void> {
  const user = await getUser(userId);
  if (!user) return;

  const catchups = await getActiveCatchUpsForUser(userId);
  const sorted = sortByPriority(catchups as (CatchUpDoc & { id: string })[]);

  // ------------------------------------------------------------------
  // PHASE 1: Check if anyone in the queue is already "live".
  // If so, connect immediately -- mutual availability is the ideal case.
  // ------------------------------------------------------------------
  for (const catchup of sorted) {
    if (state.cancelled) return;

    const otherUserId = catchup.userA === userId ? catchup.userB : catchup.userA;
    const otherUser = await getUser(otherUserId);

    if (otherUser && otherUser.status === "live") {
      // Both users are live -- connect them immediately!
      const agoraChannel = `catchup_${(catchup as any).id}_${Date.now()}`;
      const agoraToken = generateAgoraToken(agoraChannel, 0);
      const now = new Date().toISOString();

      const callId = await createCall({
        catchupId: (catchup as any).id,
        participants: [userId, otherUserId],
        agoraChannel,
        startedAt: now,
        endedAt: null,
        duration: null,
      });

      // Send ping to the other live user so their app joins the call.
      if (otherUser.fcmToken) {
        await sendCatchUpPing(
          otherUser.fcmToken,
          user.displayName,
          userId,
          (catchup as any).id,
          callId,
        );
      }

      // Cancel the other user's rotation since they're now matched.
      cancelRotation(otherUserId);

      return; // Rotation complete -- a match was found.
    }
  }

  // ------------------------------------------------------------------
  // PHASE 2: Sequential ping-and-wait for each person in the queue.
  // ------------------------------------------------------------------
  for (const catchup of sorted) {
    if (state.cancelled) return;

    const otherUserId = catchup.userA === userId ? catchup.userB : catchup.userA;
    const otherUser = await getUser(otherUserId);

    // Skip users who are already in a call.
    if (!otherUser || otherUser.status === "in_call") continue;

    // Generate call details ahead of time so the pinged user can accept instantly.
    const agoraChannel = `catchup_${(catchup as any).id}_${Date.now()}`;
    const now = new Date().toISOString();

    const callId = await createCall({
      catchupId: (catchup as any).id,
      participants: [userId, otherUserId],
      agoraChannel,
      startedAt: now,
      endedAt: null,
      duration: null,
    });

    // Send push notification to the other user.
    if (otherUser.fcmToken) {
      await sendCatchUpPing(
        otherUser.fcmToken,
        user.displayName,
        userId,
        (catchup as any).id,
        callId,
      );
    }

    // Wait up to 60 seconds for a response.
    // The accept-ping endpoint will set both users to "in_call", which we detect
    // by re-checking the caller's status after the wait.
    const accepted = await waitForAcceptance(userId, 60_000, state);

    if (state.cancelled) return;

    if (accepted) {
      // The pinged user accepted -- rotation is done.
      return;
    }

    // No response within 60s -- move to the next person in the queue.
    // (The orphaned call doc will have no endedAt, which is fine; it can be
    //  cleaned up by a background job or simply ignored.)
  }

  // ------------------------------------------------------------------
  // PHASE 3: Queue exhausted. Keep user "live" until liveTTL expires.
  // ------------------------------------------------------------------
  await waitForLiveTTLExpiry(userId, state);
}

/**
 * Wait up to `ms` milliseconds for the pinged user to accept.
 *
 * We detect acceptance by polling the caller's user status. If it flips to
 * "in_call", someone accepted. In a production system you might use a
 * Firestore onSnapshot listener for lower latency; polling every 3 seconds
 * is a pragmatic starting point.
 *
 * Returns true if the call was accepted, false on timeout.
 */
async function waitForAcceptance(
  userId: string,
  ms: number,
  state: RotationState,
): Promise<boolean> {
  const deadline = Date.now() + ms;

  while (Date.now() < deadline) {
    if (state.cancelled) return false;

    const user = await getUser(userId);
    if (user?.status === "in_call") return true;

    // Sleep 3 seconds between polls.
    await new Promise<void>((resolve) => {
      state.resolveWait = resolve;
      state.currentTimeout = setTimeout(resolve, 3_000);
    });
    state.resolveWait = null;
    state.currentTimeout = null;
  }

  return false;
}

/**
 * Wait until the user's liveTTL expires, then flip them back to "idle".
 *
 * Checks every 10 seconds. If the user goes "in_call" in the meantime
 * (e.g. someone who is live discovers them), we exit early.
 */
async function waitForLiveTTLExpiry(userId: string, state: RotationState): Promise<void> {
  while (!state.cancelled) {
    const user = await getUser(userId);
    if (!user) return;

    // If user is no longer live (someone else matched them, or they cancelled), stop.
    if (user.status !== "live") return;

    // Check if liveTTL has expired.
    if (user.liveTTL && new Date(user.liveTTL).getTime() <= Date.now()) {
      const now = new Date().toISOString();
      await updateUser(userId, {
        status: "idle",
        liveSince: null,
        liveTTL: null,
        updatedAt: now,
      });
      return;
    }

    // Sleep 10 seconds between checks.
    await new Promise<void>((resolve) => {
      state.resolveWait = resolve;
      state.currentTimeout = setTimeout(resolve, 10_000);
    });
    state.resolveWait = null;
    state.currentTimeout = null;
  }
}
