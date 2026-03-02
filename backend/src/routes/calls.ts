import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import {
  getUser,
  updateUser,
  getCatchUp,
  updateCatchUp,
  getCall,
  updateCall,
} from "../services/firestoreService.js";
import { generateAgoraToken } from "../services/agoraTokenService.js";
import { sendCallReady } from "../services/pushService.js";
import type {
  AcceptPingRequest,
  AcceptPingResponse,
  JoinCallRequest,
  JoinCallResponse,
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

      // Use the pre-created call doc from the rotation engine instead of creating a duplicate.
      const existingCall = await getCall(callId);
      if (!existingCall) {
        return reply.code(404).send({ error: "Call not found" } as any);
      }

      // Determine the other participant (User A — the one who went live).
      const otherUserId = catchup.userA === userId ? catchup.userB : catchup.userA;

      // Validate both users exist.
      const [caller, callee] = await Promise.all([getUser(userId), getUser(otherUserId)]);
      if (!caller || !callee) {
        return reply.code(404).send({ error: "One or both users not found" } as any);
      }

      // Generate Agora token for User B using the existing channel.
      const agoraToken = generateAgoraToken(existingCall.agoraChannel, 0);

      // Mark the call as started now.
      const now = new Date().toISOString();
      await updateCall(callId, { startedAt: now });

      // Set both users to "in_call".
      await Promise.all([
        updateUser(userId, { status: "in_call", liveSince: null, liveTTL: null, updatedAt: now }),
        updateUser(otherUserId, { status: "in_call", liveSince: null, liveTTL: null, updatedAt: now }),
      ]);

      // Send call_ready push to User A so they can join via /join-call.
      if (callee.fcmToken || caller.fcmToken) {
        // otherUserId is User A (the live user). caller.displayName is User B who accepted.
        const userAToken = otherUserId === catchup.userA ? callee.fcmToken : caller.fcmToken;
        const userBName = otherUserId === catchup.userA ? caller.displayName : callee.displayName;
        if (userAToken) {
          try {
            await sendCallReady(userAToken, userBName, userId, catchupId, callId);
          } catch (err) {
            console.error("Failed to send call_ready push:", err);
            // Non-fatal — User A can still poll or re-open the app.
          }
        }
      }

      return {
        agoraChannel: existingCall.agoraChannel,
        agoraToken,
        callId,
      };
    },
  );

  // ---------- POST /join-call ----------
  fastify.post<{ Body: JoinCallRequest; Reply: JoinCallResponse }>(
    "/join-call",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { callId } = request.body ?? {} as JoinCallRequest;

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

      // Generate Agora token for this user using the existing channel.
      const agoraToken = generateAgoraToken(call.agoraChannel, 0);

      return {
        agoraChannel: call.agoraChannel,
        agoraToken,
        callId,
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
