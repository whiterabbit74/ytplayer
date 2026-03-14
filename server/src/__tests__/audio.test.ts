import { describe, it, expect, vi, beforeEach } from "vitest";
import { EventEmitter } from "events";
import { buildStreamUrl, isValidVideoId, resolveAudioUrl, clearCache } from "../services/audio";

// Mock child_process.spawn
vi.mock("child_process", () => {
  return {
    spawn: vi.fn(),
  };
});

import { spawn } from "child_process";

const mockSpawn = vi.mocked(spawn);

function createMockProcess(jsonData: object, exitCode = 0) {
  const stdout = new EventEmitter();
  const stderr = new EventEmitter();
  const proc = new EventEmitter() as EventEmitter & { stdout: EventEmitter; stderr: EventEmitter };
  proc.stdout = stdout;
  proc.stderr = stderr;

  // Schedule data emission asynchronously so callers can attach listeners first
  setTimeout(() => {
    stdout.emit("data", Buffer.from(JSON.stringify(jsonData)));
    proc.emit("close", exitCode);
  }, 0);

  return proc;
}

const SAMPLE_FORMATS = {
  url: "https://example.com/audio-high.webm",
  abr: 160,
  filesize: 3000000,
  mime_type: "audio/webm; codecs=\"opus\"",
  formats: [
    {
      url: "https://example.com/video.mp4",
      vcodec: "avc1",
      acodec: "mp4a",
      abr: 128,
      content_length: 5000000,
      mime_type: "video/mp4; codecs=\"avc1.42001E, mp4a.40.2\"",
    },
    {
      url: "https://example.com/audio-low.webm",
      vcodec: "none",
      acodec: "opus",
      abr: 64,
      content_length: 1000000,
      mime_type: "audio/webm; codecs=\"opus\"",
    },
    {
      url: "https://example.com/audio-high.webm",
      vcodec: "none",
      acodec: "opus",
      abr: 160,
      content_length: 3000000,
      mime_type: "audio/webm; codecs=\"opus\"",
    },
    {
      url: "https://example.com/audio.m4a",
      vcodec: "none",
      acodec: "mp4a",
      abr: 128,
      content_length: 2000000,
      mime_type: "audio/mp4; codecs=\"mp4a.40.2\"",
    },
  ],
};

// --- isValidVideoId tests (kept from original) ---

describe("isValidVideoId", () => {
  it("accepts valid 11-char video ID", () => {
    expect(isValidVideoId("dQw4w9WgXcQ")).toBe(true);
    expect(isValidVideoId("abc_-123ABC")).toBe(true);
  });

  it("rejects invalid video IDs", () => {
    expect(isValidVideoId("")).toBe(false);
    expect(isValidVideoId("short")).toBe(false);
    expect(isValidVideoId("toolong12345")).toBe(false);
    expect(isValidVideoId("has spaces!")).toBe(false);
    expect(isValidVideoId("../etc/pass")).toBe(false);
  });
});

// --- buildStreamUrl tests (kept from original) ---

describe("buildStreamUrl", () => {
  it("throws on empty video ID", () => {
    expect(() => buildStreamUrl("")).toThrow("Invalid video ID");
  });

  it("throws on malformed video ID", () => {
    expect(() => buildStreamUrl("../../../etc")).toThrow("Invalid video ID");
    expect(() => buildStreamUrl("hello world")).toThrow("Invalid video ID");
  });

  it("returns a string URL for valid video ID", () => {
    const url = buildStreamUrl("dQw4w9WgXcQ");
    expect(typeof url).toBe("string");
    expect(url).toContain("dQw4w9WgXcQ");
  });
});

// --- resolveAudioUrl tests (new) ---

describe("resolveAudioUrl", () => {
  beforeEach(() => {
    clearCache();
    mockSpawn.mockReset();
  });

  it("rejects invalid video ID", async () => {
    await expect(resolveAudioUrl("")).rejects.toThrow("Invalid video ID");
    await expect(resolveAudioUrl("short")).rejects.toThrow("Invalid video ID");
    await expect(resolveAudioUrl("../etc/pass")).rejects.toThrow("Invalid video ID");
    expect(mockSpawn).not.toHaveBeenCalled();
  });

  it("parses yt-dlp JSON and returns best audio-only format (highest abr)", async () => {
    mockSpawn.mockReturnValueOnce(createMockProcess(SAMPLE_FORMATS) as any);

    const result = await resolveAudioUrl("dQw4w9WgXcQ");

    expect(result.audioUrl).toBe("https://example.com/audio-high.webm");
    expect(result.contentLength).toBe(3000000);
    expect(result.contentType).toBe("audio/webm");
    expect(mockSpawn).toHaveBeenCalledTimes(1);
    expect(mockSpawn).toHaveBeenCalledWith("yt-dlp", [
      "--dump-json",
      "--no-warnings",
      "--no-playlist",
      "-f",
      "bestaudio[ext=m4a]/bestaudio/best",
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    ]);
  });

  it("uses cache on second call (spawn called only once)", async () => {
    mockSpawn.mockReturnValueOnce(createMockProcess(SAMPLE_FORMATS) as any);

    const result1 = await resolveAudioUrl("dQw4w9WgXcQ");
    const result2 = await resolveAudioUrl("dQw4w9WgXcQ");

    expect(mockSpawn).toHaveBeenCalledTimes(1);
    expect(result1).toEqual(result2);
  });

  it("returns correct contentType for m4a (audio/mp4)", async () => {
    const m4aFormats = {
      url: "https://example.com/audio.m4a",
      filesize: 2000000,
      ext: "m4a",
      mime_type: "audio/mp4; codecs=\"mp4a.40.2\"",
      formats: [
        {
          url: "https://example.com/audio.m4a",
          vcodec: "none",
          acodec: "mp4a",
          abr: 128,
          content_length: 2000000,
          mime_type: "audio/mp4; codecs=\"mp4a.40.2\"",
        },
      ],
    };
    mockSpawn.mockReturnValueOnce(createMockProcess(m4aFormats) as any);

    const result = await resolveAudioUrl("abc_-123ABC");

    expect(result.audioUrl).toBe("https://example.com/audio.m4a");
    expect(result.contentType).toBe("audio/mp4");
    expect(result.contentLength).toBe(2000000);
  });

  it("returns correct contentType from mime_type field", async () => {
    const webmFormats = {
      url: "https://example.com/audio.webm",
      filesize: 1500000,
      mime_type: "audio/webm; codecs=\"opus\"",
      formats: [
        {
          url: "https://example.com/audio.webm",
          vcodec: "none",
          acodec: "opus",
          abr: 128,
          content_length: 1500000,
          mime_type: "audio/webm; codecs=\"opus\"",
        },
      ],
    };
    mockSpawn.mockReturnValueOnce(createMockProcess(webmFormats) as any);

    const result = await resolveAudioUrl("Xn7b8G0yF_M");

    expect(result.contentType).toBe("audio/webm");
  });

  it("throws when no audio-only formats are available", async () => {
    const videoOnlyFormats = {
      // url is missing here to simulate failure or we can just not provide it
      formats: [
        {
          url: "https://example.com/video.mp4",
          vcodec: "avc1",
          acodec: "none",
          abr: 0,
          content_length: 5000000,
          mime_type: "video/mp4",
        },
      ],
    };
    mockSpawn.mockReturnValueOnce(createMockProcess(videoOnlyFormats) as any);

    await expect(resolveAudioUrl("dQw4w9WgXcQ")).rejects.toThrow("No audio URL found in yt-dlp output");
  });

  it("throws when yt-dlp exits with non-zero code", async () => {
    mockSpawn.mockReturnValueOnce(createMockProcess({}, 1) as any);

    await expect(resolveAudioUrl("dQw4w9WgXcQ")).rejects.toThrow("yt-dlp exited with code 1");
  });
});
