import type { FastifyRequest, FastifyReply } from "fastify";
import admin from "firebase-admin";

/**
 * Fastify preHandler hook that verifies Firebase Auth ID tokens.
 *
 * Expects the client to send:
 *   Authorization: Bearer <idToken>
 *
 * On success, sets `request.userId` to the Firebase UID so downstream
 * handlers can identify the caller.
 */
export async function authMiddleware(
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  const authHeader = request.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    reply.code(401).send({ error: "Missing or malformed Authorization header" });
    return;
  }

  const idToken = authHeader.slice(7); // strip "Bearer "

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    request.userId = decoded.uid;
  } catch (err) {
    request.log.warn({ err }, "Invalid Firebase ID token");
    reply.code(401).send({ error: "Invalid or expired token" });
  }
}
