import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import { getActiveCatchUpsForUser, getUser } from "../services/firestoreService.js";
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

      // Sort by rotation priority.
      items.sort((a, b) => {
        // Nulls (never called) come first.
        if (a._sortLastCallAt === null && b._sortLastCallAt !== null) return -1;
        if (a._sortLastCallAt !== null && b._sortLastCallAt === null) return 1;

        // Both null: newest catch-up first (createdAt descending).
        if (a._sortLastCallAt === null && b._sortLastCallAt === null) {
          return b._sortCreatedAt.localeCompare(a._sortCreatedAt);
        }

        // Both have lastCallAt: oldest call first (ascending).
        return a._sortLastCallAt!.localeCompare(b._sortLastCallAt!);
      });

      // Strip internal sort helpers before returning.
      return items.map(({ _sortLastCallAt, _sortCreatedAt, ...rest }) => rest);
    },
  );
}
