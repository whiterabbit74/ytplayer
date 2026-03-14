import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { logger } from "../lib/logger";

const log = logger.child({ service: "auth" });
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error("JWT_SECRET environment variable is required");
}
const JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || JWT_SECRET;
const COOKIE_NAME = "musicplay_token";
const TOKEN_TTL = "90d" as const;
const MAX_AGE = 90 * 24 * 60 * 60 * 1000; // 90 days
const REFRESH_AFTER = 24 * 60 * 60; // refresh token if older than 1 day (seconds)

export interface AuthRequest extends Request {
  userId?: number;
}

export function requireAuth(req: AuthRequest, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  let token = "";
  let tokenSource: "bearer" | "cookie" | "none" = "none";
  if (authHeader?.startsWith("Bearer ")) {
    token = authHeader.slice("Bearer ".length).trim();
    tokenSource = "bearer";
  } else if (req.cookies?.[COOKIE_NAME]) {
    token = req.cookies[COOKIE_NAME];
    tokenSource = "cookie";
  }

  if (!token) {
    log.warn({ path: req.path, ip: req.ip }, "No token provided");
    res.status(401).json({ error: { code: "NOT_AUTHENTICATED", message: "Not authenticated" } });
    return;
  }

  try {
    const secret = (tokenSource === "bearer" ? JWT_ACCESS_SECRET : JWT_SECRET) as string;
    const payload = jwt.verify(token, secret) as unknown as { userId: number; iat?: number };
    req.userId = payload.userId;

    // Sliding expiration: only refresh if token is older than 1 day
    if (tokenSource === "cookie") {
      const tokenAge = Math.floor(Date.now() / 1000) - (payload.iat || 0);
      if (tokenAge > REFRESH_AFTER) {
        const newToken = jwt.sign({ userId: payload.userId }, JWT_SECRET as string, { expiresIn: TOKEN_TTL as any });
        res.cookie(COOKIE_NAME, newToken, {
          httpOnly: true,
          secure: process.env.NODE_ENV === "production",
          sameSite: "lax",
          maxAge: MAX_AGE,
        });
      }
    }

    next();
  } catch (err) {
    log.warn({ path: req.path, ip: req.ip, err }, "Invalid token");
    res.status(401).json({ error: { code: "INVALID_TOKEN", message: "Invalid token" } });
  }
}

export { JWT_SECRET, JWT_ACCESS_SECRET, COOKIE_NAME, MAX_AGE, TOKEN_TTL };
