import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import {
  getUser,
  updateUser,
  getCatchUp,
  updateCatchUp,
  createCall,
  getCall,
  updateCall,
} from "../services/firestoreService.js";
import { generateAgoraToken } from "../services/agoraTokenService.js";
import type {
  AcceptPingRequest,
  AcceptPingResponse,
  EndCallRequest,
  EndCallResponse,
} from "../types/index.js";

/**
 * Call lifecycle routes: accepting a ping (starting the Agora call)
 * and ending a call (recording duration and resetting user states).
 */
export default async function callsRoutes(fastify: FastifyInstance): Promise<void> {
  // ---------- POST /accept-ping ----------
  fastify.post<{ Body: AcceptPingRequest; Reply: AcceptPingResponse }>(
    "/accept-ping",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { catchupId, callId } = request.body ?? {} as AcceptPingRequest;

      if (!catchupId || !callId) {
        return reply.code(400).send({ error: "catchupId and callId are required" } as any);
      }

      // Validate catch-up exists and is active.
      const catchup = await getCatchUp(catchupId);
      if (!catchup || catchup.status !== "active") {
        return reply.code(404).send({ error: "Active catch-up not found" } as any);
      }

      // Determine the other participant.
      const otherUserId = catchup.userA === userId ? catchup.userB : catchup.userA;

      // Validate both users exist.
      const [caller, callee] = await Promise.all([getUser(userId), getUser(otherUserId)]);
      if (!caller || !callee) {
        return reply.code(404).send({ error: "One or both users not found" } as any);
      }

      // Generate Agora channel and token.
      const agoraChannel = `catchup_${catchupId}_${Date.now()}`;
      const agoraToken = generateAgoraToken(agoraChannel, 0);

      // Create the call document in Firestore.
      const now = new Date().toISOString();
      const newCallId = await createCall({
        catchupId,
        participants: [userId, otherUserId],
        agoraChannel,
        startedAt: now,
        endedAt: null,
        duration: null,
      });

      // Set both users to "in_call".
      await Promise.all([
        updateUser(userId, { status: "in_call", liveSince: null, liveTTL: null, updatedAt: now }),
        updateUser(otherUserId, { status: "in_call", liveSince: null, liveTTL: null, updatedAt: now }),
      ]);

      return {
        agoraChannel,
        agoraToken,
        callId: newCallId,
      };
    },
  );

  // ---------- POST /end-call ----------
  fastify.post<{ Body: EndCallRequest; Reply: EndCallResponse }>(
    "/end-call",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { callId } = request.body ?? {} as EndCallRequest;

      if (!callId) {
        return reply.code(400).send({ error: "callId is required" } as any);
      }

      const call = await getCall(callId);
      if (!call) {
        return reply.code(404).send({ error: "Call not found" } as any);
      }

      // Verify the requesting user is a participant.
      if (!call.participants.includes(userId)) {
        return reply.code(403).send({ error: "You are not a participant of this call" } as any);
      }

      // Compute duration in seconds.
      const now = new Date();
      const startedAt = new Date(call.startedAt);
      const durationSeconds = Math.round((now.getTime() - startedAt.getTime()) / 1000);

      // Update the call document.
      await updateCall(callId, {
        endedAt: now.toISOString(),
        duration: durationSeconds,
      });

      // Update the catch-up document with last call info.
      const catchup = await getCatchUp(call.catchupId);
      if (catchup) {
        await updateCatchUp(call.catchupId, {
          lastCallAt: now.toISOString(),
          callCount: catchup.callCount + 1,
        });
      }

      // Reset both participants back to "idle".
      const nowISO = now.toISOString();
      await Promise.all(
        call.participants.map((uid) =>
          updateUser(uid, { status: "idle", updatedAt: nowISO }),
        ),
      );

      return { duration: durationSeconds };
    },
  );
}
