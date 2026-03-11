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

function pickBestAudioFormat(formats: any[]): { url: string; contentLength: number; mimeType: string; httpHeaders: Record<string, string> } | null {
  // Prefer audio-only formats
  let candidates = formats.filter((f) => f.vcodec === "none" && f.acodec !== "none" && f.url);
  // Fallback: combined formats that have audio (web/ios clients don't return audio-only)
  if (candidates.length === 0) {
    candidates = formats.filter((f) => f.acodec && f.acodec !== "none" && f.url);
  }
  if (candidates.length === 0) return null;
  candidates.sort((a, b) => (b.abr || 0) - (a.abr || 0));
  const best = candidates[0];
  // mime_type from yt-dlp: "audio/webm; codecs=opus" — strip codecs for Content-Type
  const mimeType = best.mime_type
    ? best.mime_type.split(";")[0].trim()
    : "audio/webm";
  return {
    url: best.url,
    contentLength: best.content_length || best.filesize || best.filesize_approx || 0,
    mimeType,
    httpHeaders: best.http_headers || {},
  };
}

function findCookiesPath(): string | null {
  const paths = ["/app/cookie-data/cookies.txt", "/app/cookies.txt"];
  for (const p of paths) {
    if (existsSync(p)) return p;
  }
  return null;
}

function buildYtdlpArgs(videoUrl: string, useCookies: boolean): string[] {
  const args = [
    "--dump-json", "--no-warnings", "--no-playlist",
    "-f", "bestaudio*",
    "--geo-bypass",
    "--force-ipv4",
  ];

  // bgutil PO-token provider (обход YouTube JS challenge)
  const bgutilUrl = process.env.BGUTIL_POT_BASE_URL;
  if (bgutilUrl) {
    args.push("--extractor-args", `youtubepot-bgutilhttp:base_url=${bgutilUrl}`);
  }

  // JS solvers and clients
  args.push("--js-runtimes", "node");
  args.push("--remote-components", "ejs:github");
  args.push("--extractor-args", "youtube:player-client=web,ios");

  // Cookies только по запросу (fallback при "Sign in" ошибке)
  if (useCookies) {
    const cookiePath = findCookiesPath();
    if (cookiePath) {
      args.push("--cookies", cookiePath);
    }
  }

  args.push(videoUrl);
  return args;
}

function spawnYtdlp(videoId: string, useCookies: boolean): Promise<any> {
  return new Promise((resolve, reject) => {
    const url = buildStreamUrl(videoId);
    const args = buildYtdlpArgs(url, useCookies);
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
        const err = new Error(`yt-dlp exited with code ${code}`);
        (err as any).stderr = stderr;
        return reject(err);
      }
      try { resolve(JSON.parse(stdout)); }
      catch { reject(new Error("Failed to parse yt-dlp JSON")); }
    });
    proc.on("error", reject);
  });
}

const SIGN_IN_ERROR = "Sign in to confirm";

async function fetchYtdlpJson(videoId: string): Promise<any> {
  // Always use cookies when available (server IP gets bot-checked without them)
  const cookiePath = findCookiesPath();
  if (cookiePath) {
    try {
      return await spawnYtdlp(videoId, true);
    } catch (err: any) {
      log.error({ err, videoId }, "yt-dlp failed with cookies, retrying without");
    }
  }
  // Fallback: try without cookies
  return await spawnYtdlp(videoId, false);
}

export async function resolveAudioUrl(videoId: string): Promise<AudioInfo> {
  if (!videoId || !isValidVideoId(videoId)) {
    throw new Error("Invalid video ID");
  }

  const cached = cache.get(videoId);
  if (cached && cached.expiresAt > Date.now()) {
    return { audioUrl: cached.audioUrl, contentLength: cached.contentLength, contentType: cached.contentType, httpHeaders: cached.httpHeaders };
  }

  cache.delete(videoId);

  const json = await fetchYtdlpJson(videoId);
  const best = pickBestAudioFormat(json.formats || []);
  if (!best) throw new Error("No audio format found");

  const entry: CacheEntry = {
    audioUrl: best.url,
    contentLength: best.contentLength,
    contentType: best.mimeType,
    httpHeaders: best.httpHeaders,
    expiresAt: Date.now() + CACHE_TTL,
  };

  cache.set(videoId, entry);

  return { audioUrl: entry.audioUrl, contentLength: entry.contentLength, contentType: entry.contentType, httpHeaders: entry.httpHeaders };
}
