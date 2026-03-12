import { Router } from "express";
import bcrypt from "bcryptjs";
import { getDb } from "../db";
import {
  createAccessToken,
  generateRefreshToken,
  storeRefreshToken,
  consumeRefreshToken,
  revokeRefreshToken,
  getAccessTtlSeconds,
} from "../services/auth-tokens";

const router = Router();

function error(res: any, code: string, message: string, status = 400) {
  return res.status(status).json({ error: { code, message } });
}

// POST /api/v1/auth/login
router.post("/login", (req, res) => {
  const { email, password } = req.body as { email?: string; password?: string };
  if (!email || !password) {
    return error(res, "VALIDATION_ERROR", "Email and password are required", 400);
  }

  const db = getDb();
  const user = db
    .prepare("SELECT id, email, password_hash FROM users WHERE email = ?")
    .get(email) as any;

  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    console.log(`Failed login attempt for email: ${email}`);
    return error(res, "INVALID_CREDENTIALS", "Invalid email or password", 401);
  }

  const accessToken = createAccessToken(user.id);
  const refreshToken = generateRefreshToken();
  storeRefreshToken(user.id, refreshToken);

  return res.json({
    user: { id: user.id, email: user.email },
    accessToken,
    refreshToken,
    expiresIn: getAccessTtlSeconds(),
  });
});

// POST /api/v1/auth/refresh
router.post("/refresh", (req, res) => {
  const { refreshToken } = req.body as { refreshToken?: string };
  if (!refreshToken) {
    return error(res, "VALIDATION_ERROR", "refreshToken is required", 400);
  }

  const result = consumeRefreshToken(refreshToken);
  if (!result) {
    return error(res, "INVALID_REFRESH", "Invalid or expired refresh token", 401);
  }

  const accessToken = createAccessToken(result.userId);
  const newRefreshToken = generateRefreshToken();
  storeRefreshToken(result.userId, newRefreshToken);

  return res.json({
    accessToken,
    refreshToken: newRefreshToken,
    expiresIn: getAccessTtlSeconds(),
  });
});

// POST /api/v1/auth/logout
router.post("/logout", (req, res) => {
  const { refreshToken } = req.body as { refreshToken?: string };
  if (!refreshToken) {
    return error(res, "VALIDATION_ERROR", "refreshToken is required", 400);
  }

  revokeRefreshToken(refreshToken);
  return res.json({ ok: true });
});

export default router;
