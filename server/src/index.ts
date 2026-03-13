import "dotenv/config";
import express from "express";
import path from "path";
import cors from "cors";
import cookieParser from "cookie-parser";
import searchRouter from "./routes/search";
import streamRouter from "./routes/stream";
import playlistsRouter from "./routes/playlists";
import authRouter from "./routes/auth";
import v1Router from "./routes/v1";
import playerStateRouter from "./routes/player-state";
import thumbRouter from "./routes/thumb";
import favoritesRouter from "./routes/favorites";
import { initDb } from "./db";
import { requireAuth } from "./middleware/auth";
import { logger } from "./lib/logger";
import { cleanExpiredCache } from "./services/search-cache";


const app = express();
const PORT = Number(process.env.PORT) || 3001;
const HOST = "::";

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

// Request logging middleware
app.use((req, _res, next) => {
  logger.info({
    method: req.method,
    url: req.url,
    ip: req.ip,
    headers: {
      range: req.headers.range,
      authorization: req.headers.authorization ? "Present" : "Missing"
    }
  }, "Incoming request");
  next();
});

initDb();
cleanExpiredCache();

// Public routes
app.use("/api/auth", authRouter);
app.use("/api/thumb", thumbRouter);
app.use("/api/v1", v1Router);

// Protected routes
app.use("/api/search", requireAuth, searchRouter);
app.use("/api/stream", requireAuth, streamRouter);
app.use("/api/playlists", requireAuth, playlistsRouter);
app.use("/api/player", requireAuth, playerStateRouter);
app.use("/api/favorites", requireAuth, favoritesRouter);

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok" });
});

// Serve client static files if directory exists (production build)
const publicDir = path.join(__dirname, "../public");
if (require("fs").existsSync(publicDir)) {
  app.use(express.static(publicDir));
  app.get(/.*/, (req, res, next) => {
    // Don't intercept API calls
    if (req.path.startsWith("/api")) {
      return next();
    }
    res.sendFile(path.join(publicDir, "index.html"));
  });
}

const server = app.listen(PORT, HOST, () => {
  logger.info({ port: PORT, host: HOST }, "Server started");
});

// Port conflict detection
server.on("error", (err: any) => {
  if (err.code === "EADDRINUSE") {
    logger.fatal({ port: PORT }, "Port already in use. Please stop other instances.");
    process.exit(1);
  }
});

// Graceful shutdown
const shutdown = (signal: string) => {
  logger.info({ signal }, "Shutdown signal received. Closing server...");
  server.close(() => {
    logger.info("Server closed. Exiting process.");
    process.exit(0);
  });
  // Force exit after 10s if graceful closure fails
  setTimeout(() => {
    logger.error("Could not close connections in time, forceful shutdown.");
    process.exit(1);
  }, 10000);
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

// Catch unhandled errors that make the server "fall"
process.on("uncaughtException", (err) => {
  // Если это сетевая ошибка undici (fetch), не роняем сервер целиком
  if (err.message?.includes("terminated") || (err as any).code === "ECONNRESET") {
    logger.error({ err }, "Caught network-related Uncaught Exception. Keeping server alive.");
    return;
  }

  logger.fatal({ err }, "Uncaught Exception! Server is falling...");
  // Give pino time to flush
  setTimeout(() => process.exit(1), 5000);
});

process.on("unhandledRejection", (reason, promise) => {
  logger.error({ reason, promise }, "Unhandled Rejection at Promise");
});

export default app;
