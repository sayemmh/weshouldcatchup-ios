import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import { getActiveCatchUpsForUser, getUser, updateUser } from "../services/firestoreService.js";
import type { QueueItemResponse, CatchUpDoc } from "../types/index.js";

/**
 * Queue route: returns the user's active catch-up list sorted by rotation priority.
 *
 * Rotation priority:
 *   1. People never called (lastCallAt === null) come first.
 *   2. Among those, sort by createdAt descending (newest first).
 *   3. People who have been called sort by lastCallAt ascending (longest ago first).
 */
export default async function queueRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.get<{ Reply: QueueItemResponse[] }>(
    "/my-queue",
    { preHandler: authMiddleware },
    async (request, _reply) => {
      const { userId } = request;

      const catchups = await getActiveCatchUpsForUser(userId);

      // Build response items with other-user details.
      const items: (QueueItemResponse & { _sortLastCallAt: string | null; _sortCreatedAt: string })[] = [];

      await Promise.all(
        catchups.map(async (catchup: CatchUpDoc & { id?: string }) => {
          const otherUserId = catchup.userA === userId ? catchup.userB : catchup.userA;
          const otherUser = await getUser(otherUserId);

          items.push({
            catchupId: (catchup as any).id ?? "",
            otherUser: {
              name: otherUser?.displayName ?? "Unknown",
              userId: otherUserId,
            },
            lastCallAt: catchup.lastCallAt,
            callCount: catchup.callCount,
            // internal sort helpers
            _sortLastCallAt: catchup.lastCallAt,
            _sortCreatedAt: catchup.createdAt,
          });
        }),
      );

      // Use custom queue order if the user has one, falling back to default
      // rotation priority for any catchups not in the custom order.
      const user = await getUser(userId);
      const customOrder = user?.queueOrder ?? null;

      if (customOrder && customOrder.length > 0) {
        const orderMap = new Map(customOrder.map((id, idx) => [id, idx]));
        items.sort((a, b) => {
          const aIdx = orderMap.get(a.catchupId);
          const bIdx = orderMap.get(b.catchupId);
          // Both in custom order: sort by position.
          if (aIdx !== undefined && bIdx !== undefined) return aIdx - bIdx;
          // Only one in custom order: it comes first.
          if (aIdx !== undefined) return -1;
          if (bIdx !== undefined) return 1;
          // Neither in custom order: fall back to default rotation priority.
          if (a._sortLastCallAt === null && b._sortLastCallAt !== null) return -1;
          if (a._sortLastCallAt !== null && b._sortLastCallAt === null) return 1;
          if (a._sortLastCallAt === null && b._sortLastCallAt === null) {
            return b._sortCreatedAt.localeCompare(a._sortCreatedAt);
          }
          return a._sortLastCallAt!.localeCompare(b._sortLastCallAt!);
        });
      } else {
        // Default rotation priority.
        items.sort((a, b) => {
          if (a._sortLastCallAt === null && b._sortLastCallAt !== null) return -1;
          if (a._sortLastCallAt !== null && b._sortLastCallAt === null) return 1;
          if (a._sortLastCallAt === null && b._sortLastCallAt === null) {
            return b._sortCreatedAt.localeCompare(a._sortCreatedAt);
          }
          return a._sortLastCallAt!.localeCompare(b._sortLastCallAt!);
        });
      }

      // Strip internal sort helpers before returning.
      return items.map(({ _sortLastCallAt, _sortCreatedAt, ...rest }) => rest);
    },
  );

  // POST /reorder-queue -- Save the user's custom queue order.
  fastify.post<{ Body: { catchupIds: string[] }; Reply: { status: string } }>(
    "/reorder-queue",
    { preHandler: authMiddleware },
    async (request, _reply) => {
      const { userId } = request;
      const { catchupIds } = request.body as { catchupIds: string[] };

      if (!Array.isArray(catchupIds)) {
        return _reply.status(400).send({ status: "catchupIds must be an array" } as any);
      }

      await updateUser(userId, {
        queueOrder: catchupIds,
        updatedAt: new Date().toISOString(),
      } as any);

      return { status: "ok" };
    },
  );
}
