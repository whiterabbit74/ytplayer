import { spawn } from "child_process";
import { existsSync } from "fs";
import { logger } from "../lib/logger";

const log = logger.child({ service: "yt-dlp" });

const VIDEO_ID_REGEX = /^[a-zA-Z0-9_-]{11}$/;
const CACHE_TTL = 4 * 60 * 60 * 1000; // 4 hours

export interface AudioInfo {
  audioUrl: string;
  contentLength: number;
  contentType: string;
  httpHeaders: Record<string, string>;
}

interface CacheEntry extends AudioInfo {
  expiresAt: number;
}

const cache = new Map<string, CacheEntry>();

export function isValidVideoId(videoId: string): boolean {
  return VIDEO_ID_REGEX.test(videoId);
}

export function buildStreamUrl(videoId: string): string {
  if (!videoId || !isValidVideoId(videoId)) {
    throw new Error("Invalid video ID");
  }
  return `https://www.youtube.com/watch?v=${videoId}`;
}

export function clearCache(): void {
  cache.clear();
}

export function invalidateCache(videoId: string): void {
  cache.delete(videoId);
}



function findCookiesPath(): string | null {
  if (process.env.YOUTUBE_COOKIES_PATH && existsSync(process.env.YOUTUBE_COOKIES_PATH)) {
    return process.env.YOUTUBE_COOKIES_PATH;
  }
  const paths = ["/app/cookie-data/cookies.txt", "/app/cookies.txt"];
  for (const p of paths) {
    if (existsSync(p)) return p;
  }
  return null;
}

function buildYtdlpArgs(videoUrl: string, useCookies: boolean, quality: string): string[] {
  const format = quality === "low" 
    ? "worstaudio[ext=m4a]/worstaudio/worst" 
    : "bestaudio[ext=m4a]/bestaudio/best";

  // Minimal set of arguments as requested
  const args = [
    "--dump-json",
    "--no-warnings",
    "--no-playlist",
    "-f", format,
  ];

  if (useCookies) {
    const cookiePath = findCookiesPath();
    if (cookiePath) {
      args.push("--cookies", cookiePath);
    }
  }

  args.push(videoUrl);
  return args;
}

function spawnYtdlp(videoId: string, useCookies: boolean, quality: string): Promise<any> {
  return new Promise((resolve, reject) => {
    const url = buildStreamUrl(videoId);
    const args = buildYtdlpArgs(url, useCookies, quality);
    log.info({ args: args.filter(a => !a.startsWith("http")), useCookies }, "yt-dlp args");
    const proc = spawn("yt-dlp", args);

    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (chunk: Buffer) => { stdout += chunk.toString(); });
    proc.stderr.on("data", (data: Buffer) => {
      const msg = data.toString().trim();
      stderr += msg;
      log.warn({ stderr: msg }, "yt-dlp stderr");
    });
    proc.on("close", (code) => {
      if (code !== 0) {
        log.error({ code, stderr, videoId }, "yt-dlp error exit");
        const err = new Error(`yt-dlp exited with code ${code}`);
        (err as any).stderr = stderr;
        return reject(err);
      }
      try {
        const result = JSON.parse(stdout);
        resolve(result);
      } catch (e) {
        log.error({ err: e, videoId, stdout: stdout.substring(0, 500) }, "Failed to parse yt-dlp output");
        reject(new Error("Failed to parse yt-dlp JSON"));
      }
    });
    proc.on("error", (err) => {
      log.error({ err, videoId }, "yt-dlp spawn error");
      reject(err);
    });
  });
}

const SIGN_IN_ERROR = "Sign in to confirm";

async function fetchYtdlpJson(videoId: string, quality: string): Promise<any> {
  // Always use cookies when available (server IP gets bot-checked without them)
  const cookiePath = findCookiesPath();
  if (cookiePath) {
    try {
      return await spawnYtdlp(videoId, true, quality);
    } catch (err: any) {
      log.error({ err, videoId }, "yt-dlp failed with cookies, retrying without");
    }
  }
  // Fallback: try without cookies
  return await spawnYtdlp(videoId, false, quality);
}

export async function resolveAudioUrl(videoId: string, quality: string = "high"): Promise<AudioInfo> {
  if (!videoId || !isValidVideoId(videoId)) {
    throw new Error("Invalid video ID");
  }

  const cacheKey = `${videoId}_${quality}`;
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return { audioUrl: cached.audioUrl, contentLength: cached.contentLength, contentType: cached.contentType, httpHeaders: cached.httpHeaders };
  }

  cache.delete(cacheKey);

  const json = await fetchYtdlpJson(videoId, quality);
  
  // yt-dlp returns the selected format's properties at the root 
  const audioUrl = json.url;
  if (!audioUrl) throw new Error("No audio URL found in yt-dlp output");

  let mimeType = json.mime_type;
  if (mimeType) {
    mimeType = mimeType.split(";")[0].trim();
  } else {
    mimeType = json.ext === "m4a" ? "audio/mp4" : "audio/webm";
  }

  const contentLength = json.content_length || json.filesize || json.filesize_approx || 0;
  const httpHeaders = json.http_headers || {};

  log.info({ videoId, quality, ext: json.ext, mimeType, abr: json.abr }, "Selected format directly from yt-dlp");

  const entry: CacheEntry = {
    audioUrl,
    contentLength,
    contentType: mimeType,
    httpHeaders,
    expiresAt: Date.now() + CACHE_TTL,
  };

  cache.set(cacheKey, entry);

  return { audioUrl: entry.audioUrl, contentLength: entry.contentLength, contentType: entry.contentType, httpHeaders: entry.httpHeaders };
}
