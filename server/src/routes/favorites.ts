import { Router } from "express";
import { getDb } from "../db";
import type { AuthRequest } from "../middleware/auth";

const router = Router();

const YTIMG_RE = /^https?:\/\/i\.ytimg\.com\/vi\/([a-zA-Z0-9_-]{11})\//;

function normalizeThumb(thumbnail: string): string {
  const match = thumbnail.match(YTIMG_RE);
  return match ? `/api/thumb/${match[1]}` : thumbnail;
}

// GET /api/favorites - Get all favorites for user
router.get("/", (req, res) => {
  const db = getDb();
  const rows = db
    .prepare("SELECT * FROM favorites WHERE user_id = ? ORDER BY position ASC, added_at DESC")
    .all((req as AuthRequest).userId) as any[];
    
  const tracks = rows.map((row) => ({
    id: row.video_id,
    title: row.title,
    artist: row.artist,
    thumbnail: normalizeThumb(row.thumbnail),
    duration: row.duration,
  }));
  
  res.json(tracks);
});

// GET /api/favorites/ids - Get only an array of favorite video IDs
router.get("/ids", (req, res) => {
  const db = getDb();
  const rows = db
    .prepare("SELECT video_id FROM favorites WHERE user_id = ? ORDER BY position ASC, added_at DESC")
    .all((req as AuthRequest).userId) as any[];
    
  const ids = rows.map(r => r.video_id);
  res.json(ids);
});

// POST /api/favorites - Add to favorites
router.post("/", (req, res) => {
  const { video_id, title, artist, thumbnail, duration } = req.body;
  if (!video_id || !title) {
    return res.status(400).json({ error: { code: "BAD_REQUEST", message: "video_id and title are required" } });
  }

  const db = getDb();
  try {
    const maxPosRes = db
      .prepare("SELECT MAX(position) as max FROM favorites WHERE user_id = ?")
      .get((req as AuthRequest).userId) as any;
    const position = (maxPosRes?.max ?? -1) + 1;

    const result = db
      .prepare(
        "INSERT INTO favorites (user_id, video_id, title, artist, thumbnail, duration, position) VALUES (?, ?, ?, ?, ?, ?, ?)"
      )
      .run((req as AuthRequest).userId, video_id, title, artist || "", normalizeThumb(thumbnail || ""), duration || 0, position);
      
    res.status(201).json({ id: result.lastInsertRowid });
  } catch (err: any) {
    if (err.message.includes("UNIQUE constraint")) {
      return res.status(400).json({ error: { code: "ALREADY_EXISTS", message: "Already in favorites" } });
    }
    throw err;
  }
});

// PUT /api/favorites/reorder - Reorder favorites
router.put("/reorder", (req, res) => {
  const { trackIds } = req.body;
  if (!Array.isArray(trackIds)) {
    return res.status(400).json({ error: { code: "BAD_REQUEST", message: "trackIds array is required" } });
  }

  const db = getDb();
  const update = db.prepare("UPDATE favorites SET position = ? WHERE video_id = ? AND user_id = ?");
  const reorder = db.transaction((ids: string[]) => {
    ids.forEach((id, index) => {
      update.run(index, id, (req as AuthRequest).userId);
    });
  });
  reorder(trackIds);
  res.status(200).json({ ok: true });
});

// DELETE /api/favorites/:videoId - Remove from favorites
router.delete("/:videoId", (req, res) => {
  const db = getDb();
  db.prepare("DELETE FROM favorites WHERE video_id = ? AND user_id = ?").run(
    req.params.videoId,
    (req as AuthRequest).userId
  );
  res.status(204).end();
});

export default router;
