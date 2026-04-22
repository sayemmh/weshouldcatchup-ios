import type { FastifyInstance } from "fastify";
import admin from "firebase-admin";
import { Resend } from "resend";

export default async function waitlistRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /waitlist-signup — public, no auth needed
  fastify.post<{ Body: { email: string; wantTestFlight?: boolean; comment?: string } }>(
    "/waitlist-signup",
    async (request, reply) => {
      const { email, wantTestFlight, comment } = (request.body as {
        email?: string;
        wantTestFlight?: boolean;
        comment?: string;
      }) ?? {};

      if (!email || typeof email !== "string") {
        return reply.code(400).send({ error: "Email is required" });
      }

      const trimmed = email.trim().toLowerCase();
      const db = admin.firestore();

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
        wantTestFlight: wantTestFlight ?? false,
        comment: comment?.trim() || null,
        createdAt: new Date().toISOString(),
      });

      const count = (await db.collection("waitlist").count().get()).data().count;
      console.log(`[waitlist] New signup: ${trimmed} (total: ${count})`);

      // Notify via email
      const resendKey = process.env.RESEND_API_KEY;
      if (resendKey) {
        const resend = new Resend(resendKey);
        resend.emails.send({
          from: "WSCU Signups <wscu@flexbone.ai>",
          to: "sayem@flexbone.ai",
          subject: `[WSCU] New signup (#${count}): ${trimmed}`,
          html: `<p><strong>${trimmed}</strong></p>
            <p>TestFlight: ${wantTestFlight ? "Yes" : "No"}</p>
            ${comment ? `<p>Comment: ${comment}</p>` : ""}
            <p style="color:#888;font-size:12px">Total signups: ${count}</p>`,
        }).catch((err) => console.error("[waitlist] Email failed:", err));
      }

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
