import express from "express";
import path from "path";
import cors from "cors";
import cookieParser from "cookie-parser";
import dotenv from "dotenv";
import searchRouter from "./routes/search";
import streamRouter from "./routes/stream";
import playlistsRouter from "./routes/playlists";
import authRouter from "./routes/auth";
import playerStateRouter from "./routes/player-state";
import thumbRouter from "./routes/thumb";
import favoritesRouter from "./routes/favorites";
import { initDb } from "./db";
import { requireAuth } from "./middleware/auth";
import { logger } from "./lib/logger";
import { cleanExpiredCache } from "./services/search-cache";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

initDb();
cleanExpiredCache();

// Public routes
app.use("/api/auth", authRouter);
app.use("/api/thumb", thumbRouter);

// Protected routes
app.use("/api/search", requireAuth, searchRouter);
app.use("/api/stream", requireAuth, streamRouter);
app.use("/api/playlists", requireAuth, playlistsRouter);
app.use("/api/player", requireAuth, playerStateRouter);
app.use("/api/favorites", requireAuth, favoritesRouter);

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok" });
});

// Serve client static files in production
const publicDir = path.join(__dirname, "../public");
app.use(express.static(publicDir));
app.get("{*path}", (_req, res) => {
  res.sendFile(path.join(publicDir, "index.html"));
});

app.listen(PORT, () => {
  logger.info({ port: PORT }, "Server started");
});

export default app;
