import type { FastifyInstance } from "fastify";
import admin from "firebase-admin";
import { authMiddleware } from "../middleware/auth.js";
import {
  getUser,
  getCatchUp,
  updateCatchUp,
  getActiveCatchUpsForUser,
} from "../services/firestoreService.js";
import { sendInviteAccepted } from "../services/pushService.js";
import type {
  CreateCatchupResponse,
  AcceptCatchupRequest,
  RemoveCatchupRequest,
  CatchUpDoc,
} from "../types/index.js";

const db = admin.firestore;

/**
 * Catch-up management routes: create, accept, and remove catch-up pairs.
 */
export default async function catchupsRoutes(fastify: FastifyInstance): Promise<void> {
  // ---------- POST /create-catchup ----------
  fastify.post<{ Reply: CreateCatchupResponse }>(
    "/create-catchup",
    { preHandler: authMiddleware },
    async (request, _reply) => {
      const { userId } = request;
      const now = new Date().toISOString();

      const catchupData: CatchUpDoc = {
        userA: userId,
        userB: "",           // Will be filled when the invite is accepted
        status: "pending",
        createdAt: now,
        acceptedAt: null,
        removedBy: null,
        lastCallAt: null,
        callCount: 0,
      };

      const docRef = await admin
        .firestore()
        .collection("catchups")
        .add(catchupData);

      // Placeholder invite link - replace with your dynamic link domain in production.
      const inviteLink = `https://weshouldcatchup.app/invite/${docRef.id}`;

      return {
        catchupId: docRef.id,
        inviteLink,
      };
    },
  );

  // ---------- POST /accept-catchup ----------
  fastify.post<{ Body: AcceptCatchupRequest }>(
    "/accept-catchup",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { catchupId } = request.body ?? {} as AcceptCatchupRequest;

      if (!catchupId) {
        return reply.code(400).send({ error: "catchupId is required" });
      }

      const catchup = await getCatchUp(catchupId);
      if (!catchup) {
        return reply.code(404).send({ error: "Catch-up not found" });
      }

      if (catchup.status !== "pending") {
        return reply.code(409).send({ error: "Catch-up is not in a pending state" });
      }

      // The accepting user becomes userB (or either party if userB is not yet set).
      if (catchup.userB && catchup.userB !== userId) {
        return reply.code(403).send({ error: "This invite is not for you" });
      }

      if (catchup.userA === userId) {
        return reply.code(409).send({ error: "You cannot accept your own invite" });
      }

      // Prevent duplicate connections between the same two people
      const existing = await getActiveCatchUpsForUser(userId);
      const alreadyConnected = existing.some(
        (c) => c.userA === catchup.userA || c.userB === catchup.userA
      );
      if (alreadyConnected) {
        return reply.code(409).send({ error: "You're already connected with this person" });
      }

      const now = new Date().toISOString();

      await updateCatchUp(catchupId, {
        userB: userId,
        status: "active",
        acceptedAt: now,
      });

      // Send a push notification to the invite creator (userA) about acceptance.
      const otherUser = await getUser(catchup.userA);
      const acceptingUser = await getUser(userId);

      if (otherUser?.fcmToken && acceptingUser) {
        sendInviteAccepted(
          otherUser.fcmToken,
          acceptingUser.displayName,
          catchupId,
        ).catch((err) => {
          request.log.warn({ err }, "Failed to send invite-accepted push notification");
        });
      }

      return {
        catchupId,
        status: "active",
        acceptedAt: now,
      };
    },
  );

  // ---------- POST /remove-catchup ----------
  fastify.post<{ Body: RemoveCatchupRequest }>(
    "/remove-catchup",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { catchupId } = request.body ?? {} as RemoveCatchupRequest;

      if (!catchupId) {
        return reply.code(400).send({ error: "catchupId is required" });
      }

      const catchup = await getCatchUp(catchupId);
      if (!catchup) {
        return reply.code(404).send({ error: "Catch-up not found" });
      }

      // Only participants can remove a catch-up.
      if (catchup.userA !== userId && catchup.userB !== userId) {
        return reply.code(403).send({ error: "You are not a participant of this catch-up" });
      }

      await updateCatchUp(catchupId, {
        status: "removed",
        removedBy: userId,
      });

      return { status: "removed" };
    },
  );
}
