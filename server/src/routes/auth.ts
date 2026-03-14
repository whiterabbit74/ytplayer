import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { getDb } from "../db";
import { requireAuth, JWT_SECRET, COOKIE_NAME, MAX_AGE, TOKEN_TTL, type AuthRequest } from "../middleware/auth";
import { authRateLimiter } from "../middleware/rate-limit";

const router = Router();

// POST /api/auth/login
router.post("/login", authRateLimiter, (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    res.status(400).json({ error: { code: "BAD_REQUEST", message: "Email and password are required" } });
    return;
  }

  const db = getDb();
  const user = db.prepare("SELECT id, email, password_hash FROM users WHERE email = ?").get(email) as any;

  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    res.status(401).json({ error: { code: "UNAUTHORIZED", message: "Invalid email or password" } });
    return;
  }

  const token = jwt.sign({ userId: user.id }, JWT_SECRET as string, { expiresIn: TOKEN_TTL as any });
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: MAX_AGE,
  });

  res.json({ id: user.id, email: user.email });
});

// POST /api/auth/logout
router.post("/logout", (_req, res) => {
  res.clearCookie(COOKIE_NAME);
  res.json({ ok: true });
});

// GET /api/auth/me
router.get("/me", requireAuth, (req: AuthRequest, res) => {
  const db = getDb();
  const user = db.prepare("SELECT id, email FROM users WHERE id = ?").get(req.userId) as any;
  if (!user) {
    res.status(401).json({ error: { code: "NOT_FOUND", message: "User not found" } });
    return;
  }
  res.json({ id: user.id, email: user.email });
});

export default router;
