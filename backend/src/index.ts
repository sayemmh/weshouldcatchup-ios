import Fastify from "fastify";
import cors from "@fastify/cors";
import * as admin from "firebase-admin";

import liveRoutes from "./routes/live.js";
import callsRoutes from "./routes/calls.js";
import catchupsRoutes from "./routes/catchups.js";
import queueRoutes from "./routes/queue.js";
import historyRoutes from "./routes/history.js";

// ---------------------------------------------------------------------------
// Firebase Admin Initialization
// ---------------------------------------------------------------------------

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID,
});

// ---------------------------------------------------------------------------
// Fastify Server
// ---------------------------------------------------------------------------

const server = Fastify({
  logger: true,
});

// Register CORS so the mobile/web clients can talk to us.
await server.register(cors, {
  origin: true, // reflect the request origin – fine for dev; lock down in prod
});

// ---------------------------------------------------------------------------
// Register Route Plugins
// ---------------------------------------------------------------------------

await server.register(liveRoutes);
await server.register(callsRoutes);
await server.register(catchupsRoutes);
await server.register(queueRoutes);
await server.register(historyRoutes);

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------

server.get("/health", async () => ({ status: "ok" }));

// ---------------------------------------------------------------------------
// Start Server
// ---------------------------------------------------------------------------

const PORT = Number(process.env.PORT) || 8080;

try {
  await server.listen({ port: PORT, host: "0.0.0.0" });
  server.log.info(`Server listening on port ${PORT}`);
} catch (err) {
  server.log.error(err);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Graceful Shutdown
// ---------------------------------------------------------------------------

const shutdown = async (signal: string) => {
  server.log.info(`Received ${signal}. Shutting down gracefully...`);
  await server.close();
  process.exit(0);
};

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
