import { Router } from "express";
import { getDb } from "../db";
import type { AuthRequest } from "../middleware/auth";

const router = Router();

const YTIMG_RE = /^https?:\/\/i\.ytimg\.com\/vi\/([a-zA-Z0-9_-]{11})\//;

function normalizeThumb(thumbnail: string): string {
  const match = thumbnail.match(YTIMG_RE);
  return match ? `/api/thumb/${match[1]}` : thumbnail;
}

function verifyPlaylistOwner(playlistId: string, userId: number): boolean {
  const db = getDb();
  const playlist = db.prepare("SELECT id FROM playlists WHERE id = ? AND user_id = ?").get(playlistId, userId);
  return !!playlist;
}

// GET /api/playlists
router.get("/", (req, res) => {
  const db = getDb();
  const userId = (req as AuthRequest).userId;
  const playlists = db.prepare("SELECT * FROM playlists WHERE user_id = ? ORDER BY created_at DESC").all(userId) as any[];
  
  const result = playlists.map(p => {
    const tracks = db.prepare("SELECT thumbnail FROM playlist_tracks WHERE playlist_id = ? ORDER BY position LIMIT 4").all(p.id) as any[];
    return {
      ...p,
      thumbnails: tracks.map(t => t.thumbnail)
    };
  });
  
  res.json(result);
});

// POST /api/playlists
router.post("/", (req, res) => {
  const { name } = req.body;
  if (!name) return res.status(400).json({ error: "Name is required" });

  const db = getDb();
  const result = db.prepare("INSERT INTO playlists (name, user_id) VALUES (?, ?)").run(name, (req as AuthRequest).userId);
  res.status(201).json({ id: result.lastInsertRowid, name });
});

// PUT /api/playlists/:id (rename)
router.put("/:id", (req, res) => {
  if (!verifyPlaylistOwner(req.params.id, (req as AuthRequest).userId!)) {
    res.status(404).json({ error: "Playlist not found" });
    return;
  }
  const { name } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ error: "Name is required" });
  }
  const db = getDb();
  db.prepare("UPDATE playlists SET name = ? WHERE id = ? AND user_id = ?").run(name.trim(), req.params.id, (req as AuthRequest).userId);
  res.json({ id: Number(req.params.id), name: name.trim() });
});

// DELETE /api/playlists/:id
router.delete("/:id", (req, res) => {
  if (!verifyPlaylistOwner(req.params.id, (req as AuthRequest).userId!)) {
    res.status(404).json({ error: "Playlist not found" });
    return;
  }
  const db = getDb();
  db.prepare("DELETE FROM playlists WHERE id = ? AND user_id = ?").run(req.params.id, (req as AuthRequest).userId);
  res.status(204).end();
});

// GET /api/playlists/:id/tracks
router.get("/:id/tracks", (req, res) => {
  if (!verifyPlaylistOwner(req.params.id, (req as AuthRequest).userId!)) {
    res.status(404).json({ error: "Playlist not found" });
    return;
  }
  const db = getDb();
  const rows = db
    .prepare("SELECT id as _rowId, video_id, title, artist, thumbnail, duration, view_count, like_count, position FROM playlist_tracks WHERE playlist_id = ? ORDER BY position")
    .all(req.params.id) as any[];
  const tracks = rows.map((row) => ({
    id: row.video_id,
    title: row.title,
    artist: row.artist,
    thumbnail: normalizeThumb(row.thumbnail),
    duration: row.duration,
    viewCount: row.view_count,
    likeCount: row.like_count,
    _rowId: row._rowId,
  }));
  res.json(tracks);
});

// POST /api/playlists/:id/tracks
router.post("/:id/tracks", (req, res) => {
  if (!verifyPlaylistOwner(req.params.id, (req as AuthRequest).userId!)) {
    res.status(404).json({ error: "Playlist not found" });
    return;
  }
  const { video_id, title, artist, thumbnail, duration, view_count, like_count } = req.body;
  if (!video_id || !title) {
    return res.status(400).json({ error: "video_id and title are required" });
  }

  const db = getDb();
  const maxPos = db
    .prepare("SELECT MAX(position) as max FROM playlist_tracks WHERE playlist_id = ?")
    .get(req.params.id) as any;

  const position = (maxPos?.max ?? -1) + 1;

  const result = db
    .prepare(
      "INSERT INTO playlist_tracks (playlist_id, video_id, title, artist, thumbnail, duration, view_count, like_count, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    )
    .run(req.params.id, video_id, title, artist || "", normalizeThumb(thumbnail || ""), duration || 0, view_count || 0, like_count || 0, position);

  res.status(201).json({ id: result.lastInsertRowid });
});

// PUT /api/playlists/:id/tracks/reorder
router.put("/:id/tracks/reorder", (req, res) => {
  if (!verifyPlaylistOwner(req.params.id, (req as AuthRequest).userId!)) {
    res.status(404).json({ error: "Playlist not found" });
    return;
  }
  const { trackIds } = req.body;
  if (!Array.isArray(trackIds)) {
    return res.status(400).json({ error: "trackIds array is required" });
  }

  const db = getDb();
  const update = db.prepare("UPDATE playlist_tracks SET position = ? WHERE id = ? AND playlist_id = ?");
  const reorder = db.transaction((ids: number[]) => {
    ids.forEach((id, index) => {
      update.run(index, id, req.params.id);
    });
  });
  reorder(trackIds);
  res.status(200).json({ ok: true });
});

// DELETE /api/playlists/:playlistId/tracks/:trackId
router.delete("/:playlistId/tracks/:trackId", (req, res) => {
  if (!verifyPlaylistOwner(req.params.playlistId, (req as AuthRequest).userId!)) {
    res.status(404).json({ error: "Playlist not found" });
    return;
  }
  const db = getDb();
  db.prepare("DELETE FROM playlist_tracks WHERE id = ? AND playlist_id = ?").run(
    req.params.trackId,
    req.params.playlistId
  );
  res.status(204).end();
});

export default router;
