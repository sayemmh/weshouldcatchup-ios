import type { FastifyInstance } from "fastify";
import admin from "firebase-admin";
import { authMiddleware } from "../middleware/auth.js";
import { getUser } from "../services/firestoreService.js";
import type { CallHistoryItemResponse, CallDoc } from "../types/index.js";

/**
 * Call history route: returns the user's recent calls ordered by most recent first.
 */
export default async function historyRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.get<{ Reply: CallHistoryItemResponse[] }>(
    "/call-history",
    { preHandler: authMiddleware },
    async (request, _reply) => {
      const { userId } = request;

      // Query calls where the user is a participant, ordered by startedAt desc, limit 50.
      const snapshot = await admin
        .firestore()
        .collection("calls")
        .where("participants", "array-contains", userId)
        .orderBy("startedAt", "desc")
        .limit(50)
        .get();

      const items: CallHistoryItemResponse[] = [];

      await Promise.all(
        snapshot.docs.map(async (doc) => {
          const call = doc.data() as CallDoc;
          const otherUserId = call.participants.find((uid) => uid !== userId) ?? "";
          const otherUser = await getUser(otherUserId);

          items.push({
            callId: doc.id,
            otherUser: {
              name: otherUser?.displayName ?? "Unknown",
              userId: otherUserId,
            },
            startedAt: call.startedAt,
            duration: call.duration ?? 0,
          });
        }),
      );

      // Re-sort since Promise.all may resolve out of order.
      items.sort((a, b) => b.startedAt.localeCompare(a.startedAt));

      return items;
    },
  );
}
