import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import { getUser, updateUser } from "../services/firestoreService.js";
import type { UserDoc } from "../types/index.js";

/**
 * Profile management routes.
 */
export default async function profileRoutes(fastify: FastifyInstance): Promise<void> {
  // ---------- POST /update-profile ----------
  fastify.post<{ Body: { displayName?: string } }>(
    "/update-profile",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { displayName } = request.body ?? {};

      if (!displayName || displayName.trim().length === 0) {
        return reply.code(400).send({ error: "displayName is required" });
      }

      const now = new Date().toISOString();

      // Check if user doc already exists
      const existingUser = await getUser(userId);

      if (existingUser) {
        // Update existing user
        await updateUser(userId, {
          displayName: displayName.trim(),
          updatedAt: now,
        });
      } else {
        // Create a complete user doc on first profile save (onboarding)
        const newUser: UserDoc = {
          phone: "",
          displayName: displayName.trim(),
          fcmToken: null,
          status: "idle",
          liveSince: null,
          liveTTL: null,
          queueOrder: null,
          createdAt: now,
          updatedAt: now,
        };
        await updateUser(userId, newUser);
      }

      return { status: "ok" };
    },
  );

  // ---------- POST /update-fcm-token ----------
  fastify.post<{ Body: { fcmToken?: string } }>(
    "/update-fcm-token",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { fcmToken } = request.body ?? {};

      if (!fcmToken || fcmToken.trim().length === 0) {
        return reply.code(400).send({ error: "fcmToken is required" });
      }

      const now = new Date().toISOString();
      await updateUser(userId, {
        fcmToken: fcmToken.trim(),
        updatedAt: now,
      });

      return { status: "ok" };
    },
  );
}
