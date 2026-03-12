import crypto from "crypto";
import jwt from "jsonwebtoken";
import { getDb } from "../db";
import { JWT_ACCESS_SECRET } from "../middleware/auth";

const ACCESS_TTL = process.env.JWT_ACCESS_TTL || "15m";
const REFRESH_TTL_DAYS = parseInt(process.env.JWT_REFRESH_TTL_DAYS || "30", 10);

export function createAccessToken(userId: number): string {
  return jwt.sign({ userId }, JWT_ACCESS_SECRET, { expiresIn: ACCESS_TTL as any });
}

export function generateRefreshToken(): string {
  return crypto.randomBytes(32).toString("base64url");
}

export function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

export function storeRefreshToken(userId: number, refreshToken: string): void {
  const db = getDb();
  const now = Date.now();
  const expiresAt = now + REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000;
  const tokenHash = hashToken(refreshToken);
  db.prepare(
    "INSERT INTO refresh_tokens (user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?)"
  ).run(userId, tokenHash, expiresAt, now);
}

export function consumeRefreshToken(refreshToken: string): { userId: number } | null {
  const db = getDb();
  const tokenHash = hashToken(refreshToken);
  const row = db
    .prepare("SELECT user_id, expires_at FROM refresh_tokens WHERE token_hash = ?")
    .get(tokenHash) as { user_id: number; expires_at: number } | undefined;

  if (!row) return null;
  if (row.expires_at <= Date.now()) {
    db.prepare("DELETE FROM refresh_tokens WHERE token_hash = ?").run(tokenHash);
    return null;
  }

  // Rotate: delete the token upon use
  db.prepare("DELETE FROM refresh_tokens WHERE token_hash = ?").run(tokenHash);
  return { userId: row.user_id };
}

export function revokeRefreshToken(refreshToken: string): void {
  const db = getDb();
  const tokenHash = hashToken(refreshToken);
  db.prepare("DELETE FROM refresh_tokens WHERE token_hash = ?").run(tokenHash);
}

export function revokeAllUserRefreshTokens(userId: number): void {
  const db = getDb();
  db.prepare("DELETE FROM refresh_tokens WHERE user_id = ?").run(userId);
}

export function getAccessTtlSeconds(): number {
  if (ACCESS_TTL.endsWith("m")) return parseInt(ACCESS_TTL, 10) * 60;
  if (ACCESS_TTL.endsWith("h")) return parseInt(ACCESS_TTL, 10) * 3600;
  if (ACCESS_TTL.endsWith("d")) return parseInt(ACCESS_TTL, 10) * 86400;
  const asNum = parseInt(ACCESS_TTL, 10);
  return Number.isFinite(asNum) ? asNum : 900;
}
