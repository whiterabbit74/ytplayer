import { Router } from "express";
import { PassThrough } from "stream";
import { isValidVideoId, resolveAudioUrl, invalidateCache } from "../services/audio";
import { logger } from "../lib/logger";

const log = logger.child({ service: "stream" });

const router = Router();

// --- Constants ---
const INITIAL_CHUNK = 2 * 1024 * 1024;     // 2MB — first chunk to browser
const READ_AHEAD = 5 * 1024 * 1024;         // 5MB — minimum upstream fetch
const MAX_BUFFER = 50 * 1024 * 1024;         // 50MB — RAM limit per stream
const BUFFER_TTL = 60_000;                   // 60s — evict idle buffers
const LOW_WATER = 1 * 1024 * 1024;           // 1MB — trigger proactive read-ahead
const SWEEP_INTERVAL = 2 * 60_000;           // 2min — safety sweep

// --- StreamBuffer ---
class StreamBuffer {
  videoId: string;
  bufferStart = 0;
  bufferEnd = 0;
  chunks: Buffer[] = [];
  totalBuffered = 0;
  filling = false;
  activeAbort: AbortController | null = null;
  private timer: ReturnType<typeof setTimeout> | null = null;

  // Upstream info needed for proactive read-ahead
  audioUrl = "";
  httpHeaders: Record<string, string> = {};
  contentLength = 0;

  constructor(videoId: string) {
    this.videoId = videoId;
    this.touch();
  }

  touch(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = setTimeout(() => this.destroy(), BUFFER_TTL);
  }

  covers(start: number, end: number): boolean {
    return start >= this.bufferStart && end <= this.bufferEnd && this.totalBuffered > 0;
  }

  isContiguous(start: number): boolean {
    return start >= this.bufferStart && start <= this.bufferEnd && this.totalBuffered > 0;
  }

  slice(start: number, end: number): Buffer {
    const length = end - start + 1;
    const result = Buffer.allocUnsafe(length);
    let resultOffset = 0;
    let currentChunkStart = this.bufferStart;

    for (const chunk of this.chunks) {
      const chunkEnd = currentChunkStart + chunk.length - 1;
      
      // If chunk overlaps with the requested range [start, end]
      if (chunkEnd >= start && currentChunkStart <= end) {
        const sliceStart = Math.max(0, start - currentChunkStart);
        const sliceEnd = Math.min(chunk.length, end - currentChunkStart + 1);
        const bytesToCopy = sliceEnd - sliceStart;
        
        if (bytesToCopy > 0) {
          chunk.copy(result, resultOffset, sliceStart, sliceEnd);
          resultOffset += bytesToCopy;
        }
      }
      
      currentChunkStart += chunk.length;
      if (currentChunkStart > end) break;
    }
    
    return result;
  }

  append(chunk: Buffer): void {
    this.chunks.push(chunk);
    this.totalBuffered += chunk.length;
    this.bufferEnd = this.bufferStart + this.totalBuffered - 1;

    // Trim from front if over MAX_BUFFER
    while (this.totalBuffered > MAX_BUFFER && this.chunks.length > 1) {
      const removed = this.chunks.shift()!;
      this.totalBuffered -= removed.length;
      this.bufferStart += removed.length;
    }
  }

  reset(newStart: number): void {
    this.chunks = [];
    this.totalBuffered = 0;
    this.bufferStart = newStart;
    this.bufferEnd = newStart;
  }

  abortFill(): void {
    if (this.activeAbort) {
      this.activeAbort.abort();
      this.activeAbort = null;
    }
    this.filling = false;
  }

  destroy(): void {
    this.abortFill();
    if (this.timer) clearTimeout(this.timer);
    this.chunks = [];
    this.totalBuffered = 0;
    buffers.delete(this.videoId);
    log.debug({ videoId: this.videoId }, "Buffer destroyed");
  }

  /** Bytes remaining ahead from a given position */
  remaining(from: number): number {
    if (from > this.bufferEnd || from < this.bufferStart) return 0;
    return this.bufferEnd - from + 1;
  }
}

// --- Global buffer map ---
const buffers = new Map<string, StreamBuffer>();

function getOrCreateBuffer(videoId: string): StreamBuffer {
  let buf = buffers.get(videoId);
  if (!buf) {
    buf = new StreamBuffer(videoId);
    buffers.set(videoId, buf);
  }
  buf.touch();
  return buf;
}

// Safety sweep — evict any leaked buffers
setInterval(() => {
  // TTL timers handle cleanup; this is a safety net
  for (const [id, buf] of buffers) {
    if (buf.totalBuffered === 0 && !buf.filling) {
      buf.destroy();
      log.debug({ videoId: id }, "Sweep cleaned empty buffer");
    }
  }
}, SWEEP_INTERVAL);

// --- Helpers ---

function parseRange(header: string, total: number): { start: number; end: number } | null {
  const match = header.match(/bytes=(\d+)-(\d*)/);
  if (!match) return null;
  const start = parseInt(match[1], 10);
  const end = match[2] ? parseInt(match[2], 10) : total - 1;
  if (start >= total || end >= total || start > end) return null;
  return { start, end };
}

/**
 * Read upstream body, pipe first `browserBytes` to PassThrough, rest into StreamBuffer.
 * Returns the PassThrough stream to pipe to response.
 */
function splitUpstream(
  upstreamBody: ReadableStream<Uint8Array>,
  buf: StreamBuffer,
  browserBytes: number,
  upstreamStart: number,
): PassThrough {
  const pt = new PassThrough();
  let sentToClient = 0;

  buf.reset(upstreamStart);

  const reader = (upstreamBody as any).getReader() as ReadableStreamDefaultReader<Uint8Array>;

  (async () => {
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = Buffer.from(value);
        const remaining = browserBytes - sentToClient;

        if (remaining > 0) {
          if (chunk.length <= remaining) {
            // Entire chunk goes to client
            pt.write(chunk);
            sentToClient += chunk.length;
            // Also store in buffer for future range requests
            buf.append(chunk);
          } else {
            // Split: part to client, rest to buffer
            const clientPart = chunk.subarray(0, remaining);
            const bufferPart = chunk.subarray(remaining);
            pt.write(clientPart);
            sentToClient += clientPart.length;
            buf.append(chunk); // Store entire chunk for contiguity
          }

          if (sentToClient >= browserBytes) {
            pt.end();
          }
        } else {
          // Client already served — just buffer
          buf.append(chunk);
        }
      }
    } catch (err: any) {
      if (err.name !== "AbortError") {
        log.error({ err }, "Upstream read error");
      }
    } finally {
      if (!pt.writableEnded) pt.end();
      buf.filling = false;
    }
  })();

  return pt;
}

/**
 * Proactively fetch next READ_AHEAD bytes into buffer (background).
 */
function proactiveReadAhead(buf: StreamBuffer): void {
  if (buf.filling) return;
  if (buf.bufferEnd + 1 >= buf.contentLength) return;

  const start = buf.bufferEnd + 1;
  const end = Math.min(start + READ_AHEAD - 1, buf.contentLength - 1);

  log.debug({ videoId: buf.videoId, start, end }, "Read-ahead started");

  buf.filling = true;
  const abort = new AbortController();
  buf.activeAbort = abort;

  fetch(buf.audioUrl, {
    headers: { ...buf.httpHeaders, Range: `bytes=${start}-${end}` },
    signal: abort.signal,
  })
    .then(async (upstream) => {
      if (!upstream.body || (!upstream.ok && upstream.status !== 206)) {
        buf.filling = false;
        return;
      }
      const reader = (upstream.body as any).getReader() as ReadableStreamDefaultReader<Uint8Array>;
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buf.append(Buffer.from(value));
        }
      } catch (err: any) {
        if (err.name !== "AbortError") {
          log.error({ err }, "Read-ahead error");
        }
      } finally {
        buf.filling = false;
        buf.activeAbort = null;
      }
    })
    .catch((err) => {
      if (err.name !== "AbortError") {
        log.error({ err }, "Read-ahead fetch error");
      }
      buf.filling = false;
      buf.activeAbort = null;
    });
}

// --- Route handler ---
router.get("/:videoId", async (req, res) => {
  const { videoId } = req.params;
  const quality = req.query.quality === "low" ? "low" : "high";

  if (!videoId || !isValidVideoId(videoId)) {
    return res.status(400).json({ error: "Invalid video ID" });
  }

  let audioInfo;
  try {
    audioInfo = await resolveAudioUrl(videoId, quality);
  } catch (err) {
    log.error({ err, videoId, quality }, "Failed to resolve audio URL");
    return res.status(502).json({ error: "Failed to resolve audio" });
  }

  let { audioUrl, contentLength, contentType, httpHeaders } = audioInfo;

  // Update buffer with current upstream info
  const bufferKey = `${videoId}_${quality}`;
  const buf = getOrCreateBuffer(bufferKey);
  buf.videoId = bufferKey; // Use combination for logging
  buf.audioUrl = audioUrl;
  buf.httpHeaders = httpHeaders;
  buf.contentLength = contentLength;

  function upstreamHeaders(rangeValue: string): Record<string, string> {
    return { ...httpHeaders, Range: rangeValue };
  }

  const rangeHeader = req.headers.range;

  // ---- Full Download ----
  if (req.headers["x-full-download"] === "true") {
    const upstream = await fetch(audioUrl, { headers: httpHeaders }).catch(() => null);
    if (!upstream || !upstream.ok) {
      return res.status(502).json({ error: "Upstream fetch failed" });
    }
    res.status(200);
    res.setHeader("Content-Type", contentType);
    res.setHeader("Content-Length", contentLength);
    if (!upstream.body) return res.end();
    const { Readable } = require("stream");
    const stream = Readable.fromWeb(upstream.body as any);
    stream.on("error", (err: any) => {
      log.error({ err, videoId }, "Full download stream error");
    });
    stream.pipe(res);
    return;
  }

  // ---- No Range header: first request ----
  if (!rangeHeader) {
    const browserEnd = Math.min(contentLength - 1, INITIAL_CHUNK - 1);
    const upstreamEnd = Math.min(contentLength - 1, READ_AHEAD - 1);

    log.debug({ videoId, upstreamEnd, browserEnd }, "Buffer miss (initial)");

    const upstream = await fetch(audioUrl, {
      headers: upstreamHeaders(`bytes=0-${upstreamEnd}`),
    }).catch(() => null);

    if (!upstream || (!upstream.ok && upstream.status !== 206)) {
      return res.status(502).json({ error: "Upstream fetch failed" });
    }

    res.status(206);
    res.setHeader("Content-Type", contentType);
    res.setHeader("Accept-Ranges", "bytes");
    res.setHeader("Content-Range", `bytes 0-${browserEnd}/${contentLength}`);
    res.setHeader("Content-Length", browserEnd + 1);

    if (!upstream.body) {
      return res.end();
    }

    buf.filling = true;
    const pt = splitUpstream(upstream.body as any, buf, browserEnd + 1, 0);
    pt.pipe(res);
    req.on("close", () => {
      pt.destroy();
    });
    return;
  }

  // ---- With Range header ----
  const range = parseRange(rangeHeader, contentLength);
  if (!range) {
    return res.status(416).json({ error: "Range not satisfiable" });
  }

  const { start, end } = range;

  // --- Buffer HIT ---
  if (buf.covers(start, end)) {
    log.debug({ videoId, start, end }, "Buffer hit");
    buf.touch();

    const data = buf.slice(start, end);
    res.status(206);
    res.setHeader("Content-Type", contentType);
    res.setHeader("Accept-Ranges", "bytes");
    res.setHeader("Content-Range", `bytes ${start}-${end}/${contentLength}`);
    res.setHeader("Content-Length", data.length);
    res.end(data);

    // Trigger proactive read-ahead if buffer running low
    if (buf.remaining(end + 1) < LOW_WATER) {
      proactiveReadAhead(buf);
    }
    return;
  }

  // --- Buffer MISS: fetch from upstream ---
  // If seeking (start outside buffer window), reset
  if (!buf.isContiguous(start)) {
    buf.abortFill();
    buf.reset(start);
  }

  const upstreamStart = start;
  const upstreamEnd = Math.min(upstreamStart + READ_AHEAD - 1, contentLength - 1);
  const actualEnd = Math.min(end, upstreamEnd);
  const browserBytes = actualEnd - start + 1;

  log.debug({ videoId, upstreamStart, upstreamEnd, start, end, actualEnd }, "Buffer miss");

  const MAX_ATTEMPTS = 2;
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    let upstream: Response;
    try {
      upstream = await fetch(audioUrl, {
        headers: upstreamHeaders(`bytes=${upstreamStart}-${upstreamEnd}`),
      });
    } catch (err) {
      log.error({ err, videoId }, "Upstream fetch failed");
      return res.status(502).json({ error: "Upstream fetch failed" });
    }

    if (upstream.status === 403 && attempt === 0) {
      invalidateCache(bufferKey);
      try {
        const fresh = await resolveAudioUrl(videoId, quality);
        audioUrl = fresh.audioUrl;
        contentLength = fresh.contentLength;
        contentType = fresh.contentType;
        httpHeaders = fresh.httpHeaders;
        buf.audioUrl = audioUrl;
        buf.httpHeaders = httpHeaders;
        buf.contentLength = contentLength;
      } catch (err) {
        log.error({ err, videoId, quality }, "Failed to re-resolve audio URL");
        return res.status(502).json({ error: "Failed to resolve audio" });
      }
      continue;
    }

    if (!upstream.ok && upstream.status !== 206) {
      return res.status(502).json({ error: `Upstream returned ${upstream.status}` });
    }

    res.status(206);
    res.setHeader("Content-Type", contentType);
    res.setHeader("Accept-Ranges", "bytes");
    res.setHeader("Content-Range", `bytes ${start}-${actualEnd}/${contentLength}`);
    res.setHeader("Content-Length", browserBytes);

    if (!upstream.body) {
      return res.end();
    }

    buf.filling = true;
    const pt = splitUpstream(upstream.body as any, buf, browserBytes, upstreamStart);
    pt.pipe(res);
    req.on("close", () => {
      pt.destroy();
    });
    return;
  }

  return res.status(502).json({ error: "Failed after retries" });
});

export default router;
