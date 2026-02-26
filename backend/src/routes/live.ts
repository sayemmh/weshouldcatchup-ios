import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import { getUser, updateUser } from "../services/firestoreService.js";
import { startRotation, cancelRotation } from "../services/rotationEngine.js";
import type { GoLiveResponse } from "../types/index.js";

/**
 * /go-live and /cancel-live routes.
 *
 * Going live sets the user's status to "live", records liveSince and a 10-minute
 * TTL window, then kicks off the rotation engine in the background.
 */
export default async function liveRoutes(fastify: FastifyInstance): Promise<void> {
  // ---------- POST /go-live ----------
  fastify.post<{ Reply: GoLiveResponse }>(
    "/go-live",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;

      const user = await getUser(userId);
      if (!user) {
        return reply.code(404).send({ error: "User not found" } as any);
      }

      if (user.status === "in_call") {
        return reply.code(409).send({ error: "Cannot go live while in a call" } as any);
      }

      const now = new Date().toISOString();
      const liveTTL = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // +10 minutes

      await updateUser(userId, {
        status: "live",
        liveSince: now,
        liveTTL,
        updatedAt: now,
      });

      // Fire-and-forget: start the rotation engine for this user.
      // We intentionally do NOT await this so the HTTP response returns immediately.
      startRotation(userId).catch((err) => {
        request.log.error({ err, userId }, "Rotation engine error");
      });

      return { status: "live", liveTTL };
    },
  );

  // ---------- POST /cancel-live ----------
  fastify.post(
    "/cancel-live",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;

      const user = await getUser(userId);
      if (!user) {
        return reply.code(404).send({ error: "User not found" });
      }

      // Cancel any in-progress rotation for this user.
      cancelRotation(userId);

      const now = new Date().toISOString();

      await updateUser(userId, {
        status: "idle",
        liveSince: null,
        liveTTL: null,
        updatedAt: now,
      });

      return { status: "idle" };
    },
  );
}
