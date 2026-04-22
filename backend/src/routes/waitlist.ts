import type { FastifyInstance } from "fastify";
import admin from "firebase-admin";

export default async function waitlistRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /waitlist-signup — public, no auth needed
  fastify.post<{ Body: { email: string } }>(
    "/waitlist-signup",
    async (request, reply) => {
      const { email } = (request.body as { email?: string }) ?? {};

      if (!email || typeof email !== "string") {
        return reply.code(400).send({ error: "Email is required" });
      }

      const trimmed = email.trim().toLowerCase();
      const db = admin.firestore();

      // Check for duplicate
      const existing = await db
        .collection("waitlist")
        .where("email", "==", trimmed)
        .limit(1)
        .get();

      if (!existing.empty) {
        return { duplicate: true, message: "Already signed up" };
      }

      await db.collection("waitlist").add({
        email: trimmed,
        createdAt: new Date().toISOString(),
      });

      const count = (await db.collection("waitlist").count().get()).data().count;
      console.log(`[waitlist] New signup: ${trimmed} (total: ${count})`);

      return { success: true };
    },
  );

  // GET /waitlist-signup — list all signups (for your use)
  fastify.get("/waitlist-signup", async () => {
    const db = admin.firestore();
    const snapshot = await db.collection("waitlist").orderBy("createdAt", "desc").get();
    const emails = snapshot.docs.map((doc) => doc.data().email);
    return { count: emails.length, emails };
  });
}
