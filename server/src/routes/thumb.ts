import { Router } from "express";
import { logger } from "../lib/logger";

const log = logger.child({ service: "thumb" });
const router = Router();

const VIDEO_ID_RE = /^[a-zA-Z0-9_-]{11}$/;
const THUMB_URL = (id: string) =>
  `https://i.ytimg.com/vi/${id}/mqdefault.jpg`;

// --- In-memory cache ---
interface CacheEntry {
  buffer: Buffer;
  contentType: string;
  ts: number;
}

const cache = new Map<string, CacheEntry>();
const MAX_ENTRIES = 500;
const TTL = 24 * 60 * 60 * 1000; // 24h

function evict() {
  if (cache.size <= MAX_ENTRIES) return;
  // Remove oldest entries
  const sorted = [...cache.entries()].sort((a, b) => a[1].ts - b[1].ts);
  const toRemove = sorted.slice(0, cache.size - MAX_ENTRIES);
  for (const [key] of toRemove) cache.delete(key);
}

router.get("/:videoId", async (req, res) => {
  const { videoId } = req.params;

  if (!videoId || !VIDEO_ID_RE.test(videoId)) {
    return res.status(400).json({ error: "Invalid video ID" });
  }

  // Check cache
  const cached = cache.get(videoId);
  if (cached && Date.now() - cached.ts < TTL) {
    res.setHeader("Content-Type", cached.contentType);
    res.setHeader("Cache-Control", "public, max-age=86400");
    return res.end(cached.buffer);
  }

  try {
    const upstream = await fetch(THUMB_URL(videoId), {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      }
    });
    if (!upstream.ok) {
      return res.status(upstream.status).json({ error: "Upstream error" });
    }

    const contentType = upstream.headers.get("content-type") || "image/jpeg";
    const buffer = Buffer.from(await upstream.arrayBuffer());

    // Store in cache
    cache.set(videoId, { buffer, contentType, ts: Date.now() });
    evict();

    res.setHeader("Content-Type", contentType);
    res.setHeader("Cache-Control", "public, max-age=604800, immutable"); // 7 days
    res.end(buffer);
  } catch (err) {
    log.error({ err, videoId }, "Fetch error");
    res.status(502).json({ error: "Failed to fetch thumbnail" });
  }
});

export default router;
