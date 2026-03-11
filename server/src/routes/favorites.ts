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
    .prepare("SELECT * FROM favorites WHERE user_id = ? ORDER BY added_at DESC")
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
    .prepare("SELECT video_id FROM favorites WHERE user_id = ?")
    .all((req as AuthRequest).userId) as any[];
    
  const ids = rows.map(r => r.video_id);
  res.json(ids);
});

// POST /api/favorites - Add to favorites
router.post("/", (req, res) => {
  const { video_id, title, artist, thumbnail, duration } = req.body;
  if (!video_id || !title) {
    return res.status(400).json({ error: "video_id and title are required" });
  }

  const db = getDb();
  try {
    const result = db
      .prepare(
        "INSERT INTO favorites (user_id, video_id, title, artist, thumbnail, duration) VALUES (?, ?, ?, ?, ?, ?)"
      )
      .run((req as AuthRequest).userId, video_id, title, artist || "", normalizeThumb(thumbnail || ""), duration || 0);
      
    res.status(201).json({ id: result.lastInsertRowid });
  } catch (err: any) {
    // Check for UNIQUE constraint violation
    if (err.message.includes("UNIQUE constraint")) {
      return res.status(400).json({ error: "Already in favorites" });
    }
    throw err;
  }
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
