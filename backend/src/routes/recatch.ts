import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import {
  getUser,
  getCatchUp,
  updateCatchUp,
  getCaughtUpCatchUpsForUser,
  isCaughtUp,
} from "../services/firestoreService.js";
import { sendRecatchRequest, sendRecatchAccepted, sendQueueUpdated } from "../services/pushService.js";
import type {
  CaughtUpItemResponse,
  RecatchState,
  CatchUpDoc,
} from "../types/index.js";

/**
 * "Caught Up" list + re-catch flow.
 *
 * Once two people have had a call, their pair auto-moves to the Caught Up list
 * (see /end-call). To talk again, one taps "Catch up again" (request-recatch);
 * the other accepts (accept-recatch), which returns the pair to both active queues.
 */
export default async function recatchRoutes(fastify: FastifyInstance): Promise<void> {
  // ---------- GET /caught-up ----------
  fastify.get<{ Reply: CaughtUpItemResponse[] }>(
    "/caught-up",
    { preHandler: authMiddleware },
    async (request, _reply) => {
      const { userId } = request;

      const catchups = await getCaughtUpCatchUpsForUser(userId);

      const items: (CaughtUpItemResponse & { _lastCallAt: string | null })[] = [];

      await Promise.all(
        catchups.map(async (catchup: CatchUpDoc & { id?: string }) => {
          const otherUserId = catchup.userA === userId ? catchup.userB : catchup.userA;
          const otherUser = otherUserId ? await getUser(otherUserId) : null;

          // Compute the re-catch state from this viewer's perspective.
          let state: RecatchState = "idle";
          if (catchup.recatchRequestedBy) {
            state = catchup.recatchRequestedBy === userId ? "requested_by_me" : "incoming";
          }

          items.push({
            catchupId: (catchup as any).id ?? "",
            otherUser: {
              name: otherUser?.displayName ?? "Unknown",
              userId: otherUserId,
            },
            lastCallAt: catchup.lastCallAt,
            callCount: catchup.callCount,
            state,
            _lastCallAt: catchup.lastCallAt,
          });
        }),
      );

      // Incoming requests first, then most recently caught-up first.
      items.sort((a, b) => {
        if (a.state === "incoming" && b.state !== "incoming") return -1;
        if (a.state !== "incoming" && b.state === "incoming") return 1;
        return (b._lastCallAt ?? "").localeCompare(a._lastCallAt ?? "");
      });

      return items.map(({ _lastCallAt, ...rest }) => rest);
    },
  );

  // ---------- POST /request-recatch ----------
  fastify.post<{ Body: { catchupId: string } }>(
    "/request-recatch",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { catchupId } = request.body ?? {} as { catchupId: string };

      if (!catchupId) {
        return reply.code(400).send({ error: "catchupId is required" });
      }

      const catchup = await getCatchUp(catchupId);
      if (!catchup) {
        return reply.code(404).send({ error: "Catch-up not found" });
      }
      if (catchup.userA !== userId && catchup.userB !== userId) {
        return reply.code(403).send({ error: "You are not a participant of this catch-up" });
      }
      if (catchup.status !== "active" || !isCaughtUp(catchup)) {
        return reply.code(409).send({ error: "This catch-up is not in the Caught Up list" });
      }

      await updateCatchUp(catchupId, { recatchRequestedBy: userId });

      // Notify the other person (best effort — also visible in their Caught Up list).
      const otherUserId = catchup.userA === userId ? catchup.userB : catchup.userA;
      const [otherUser, me] = await Promise.all([getUser(otherUserId), getUser(userId)]);
      if (otherUser?.fcmToken && me) {
        sendRecatchRequest(otherUser.fcmToken, me.displayName, userId, catchupId).catch((err) => {
          request.log.warn({ err }, "Failed to send recatch_request push");
        });
      }

      return { status: "requested" };
    },
  );

  // ---------- POST /accept-recatch ----------
  fastify.post<{ Body: { catchupId: string } }>(
    "/accept-recatch",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { catchupId } = request.body ?? {} as { catchupId: string };

      if (!catchupId) {
        return reply.code(400).send({ error: "catchupId is required" });
      }

      const catchup = await getCatchUp(catchupId);
      if (!catchup) {
        return reply.code(404).send({ error: "Catch-up not found" });
      }
      if (catchup.userA !== userId && catchup.userB !== userId) {
        return reply.code(403).send({ error: "You are not a participant of this catch-up" });
      }
      if (!catchup.recatchRequestedBy) {
        return reply.code(409).send({ error: "No re-catch request to accept" });
      }
      // You can't accept your own request — only the other person can.
      if (catchup.recatchRequestedBy === userId) {
        return reply.code(409).send({ error: "You can't accept your own request" });
      }

      // Re-activate the pair: back into both active queues, request cleared.
      await updateCatchUp(catchupId, { caughtUp: false, recatchRequestedBy: null });

      const requesterId = catchup.recatchRequestedBy;
      const [requester, me] = await Promise.all([getUser(requesterId), getUser(userId)]);

      // Tell the requester they're back in the queue; refresh both queues.
      if (requester?.fcmToken && me) {
        sendRecatchAccepted(requester.fcmToken, me.displayName, userId, catchupId).catch((err) => {
          request.log.warn({ err }, "Failed to send recatch_accepted push");
        });
      }
      if (me?.fcmToken) {
        sendQueueUpdated(me.fcmToken).catch(() => {});
      }

      return { status: "active" };
    },
  );

  // ---------- POST /decline-recatch ----------
  fastify.post<{ Body: { catchupId: string } }>(
    "/decline-recatch",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { catchupId } = request.body ?? {} as { catchupId: string };

      if (!catchupId) {
        return reply.code(400).send({ error: "catchupId is required" });
      }

      const catchup = await getCatchUp(catchupId);
      if (!catchup) {
        return reply.code(404).send({ error: "Catch-up not found" });
      }
      if (catchup.userA !== userId && catchup.userB !== userId) {
        return reply.code(403).send({ error: "You are not a participant of this catch-up" });
      }

      // Clear the request; the pair stays caught up. Either party may dismiss it.
      await updateCatchUp(catchupId, { recatchRequestedBy: null });

      return { status: "declined" };
    },
  );
}
