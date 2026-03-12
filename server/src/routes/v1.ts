import { Router } from "express";
import searchRouter from "./search";
import streamRouter from "./stream";
import playlistsRouter from "./playlists";
import playerStateRouter from "./player-state";
import thumbRouter from "./thumb";
import favoritesRouter from "./favorites";
import authV1Router from "./auth-v1";
import { requireAuth } from "../middleware/auth";

const router = Router();

// Public
router.use("/auth", authV1Router);
router.use("/thumb", thumbRouter);

// Protected
router.use("/search", requireAuth, searchRouter);
router.use("/stream", requireAuth, streamRouter);
router.use("/playlists", requireAuth, playlistsRouter);
router.use("/player", requireAuth, playerStateRouter);
router.use("/favorites", requireAuth, favoritesRouter);

export default router;
