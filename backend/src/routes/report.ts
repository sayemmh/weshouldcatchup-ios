import type { FastifyInstance } from "fastify";
import admin from "firebase-admin";
import { authMiddleware } from "../middleware/auth.js";
import { updateCatchUp, getUser } from "../services/firestoreService.js";

export default async function reportRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post<{ Body: { catchupId: string; reportedUserId: string } }>(
    "/report-user",
    { preHandler: authMiddleware },
    async (request, reply) => {
      const { userId } = request;
      const { catchupId, reportedUserId } = (request.body as {
        catchupId?: string;
        reportedUserId?: string;
      }) ?? {};

      if (!catchupId || !reportedUserId) {
        return reply.code(400).send({ error: "catchupId and reportedUserId are required" });
      }

      const db = admin.firestore();

      // Store the report
      await db.collection("reports").add({
        reporterId: userId,
        reportedUserId,
        catchupId,
        createdAt: new Date().toISOString(),
        status: "pending",
      });

      // Remove the catchup (block)
      await updateCatchUp(catchupId, {
        status: "removed",
        removedBy: userId,
      });

      // Notify the other user's queue to refresh
      const otherUser = await getUser(reportedUserId);
      if (otherUser?.fcmToken) {
        admin.messaging().send({
          token: otherUser.fcmToken,
          data: { type: "queue_updated" },
          apns: { payload: { aps: { contentAvailable: true } } },
        }).catch(() => {});
      }

      return { status: "reported" };
    },
  );
}
