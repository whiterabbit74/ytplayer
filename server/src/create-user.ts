import { initDb, getDb } from "./db";
import bcrypt from "bcryptjs";
import dotenv from "dotenv";

dotenv.config();

const args = process.argv.slice(2);
const emailIdx = args.indexOf("--email");
const passwordIdx = args.indexOf("--password");

if (emailIdx === -1 || passwordIdx === -1) {
  console.error("Usage: npm run create-user -- --email user@example.com --password mypassword");
  process.exit(1);
}

const email = args[emailIdx + 1];
const password = args[passwordIdx + 1];

if (!email || !password) {
  console.error("Email and password are required");
  process.exit(1);
}

initDb();
const db = getDb();

const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(email) as { id: number } | undefined;
const hash = bcrypt.hashSync(password, 10);

if (existing) {
  db.prepare("UPDATE users SET password_hash = ? WHERE id = ?").run(hash, existing.id);
  console.log(`User updated: ${email} (id: ${existing.id})`);
} else {
  const result = db.prepare("INSERT INTO users (email, password_hash) VALUES (?, ?)").run(email, hash);
  console.log(`User created: ${email} (id: ${result.lastInsertRowid})`);
}
