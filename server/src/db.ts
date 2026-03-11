import Database from "better-sqlite3";

let db: Database.Database;

export function initDb(path: string = process.env.DB_PATH || "./musicplay.db"): void {
  db = new Database(path);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");

  db.exec(`
    CREATE TABLE IF NOT EXISTS playlists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS playlist_tracks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
      video_id TEXT NOT NULL,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      thumbnail TEXT NOT NULL,
      duration INTEGER DEFAULT 0,
      view_count INTEGER DEFAULT 0,
      like_count INTEGER DEFAULT 0,
      position INTEGER NOT NULL,
      added_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS player_state (
      user_id INTEGER PRIMARY KEY REFERENCES users(id),
      queue TEXT NOT NULL DEFAULT '[]',
      current_index INTEGER NOT NULL DEFAULT 0,
      position REAL NOT NULL DEFAULT 0,
      repeat_mode TEXT NOT NULL DEFAULT 'off',
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS search_cache (
      query TEXT PRIMARY KEY,
      video_ids TEXT NOT NULL,
      next_page_token TEXT,
      created_at INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_search_cache_created_at ON search_cache(created_at);

    CREATE TABLE IF NOT EXISTS favorites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      video_id TEXT NOT NULL,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      thumbnail TEXT NOT NULL,
      duration INTEGER DEFAULT 0,
      added_at TEXT DEFAULT (datetime('now')),
      UNIQUE(user_id, video_id)
    );
    CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_id_position ON playlist_tracks(playlist_id, position);
    CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
    CREATE INDEX IF NOT EXISTS idx_playlists_user_id ON playlists(user_id);
  `);

  // Миграция: добавить колонки если таблица уже существует без них
  const columns = db.prepare("PRAGMA table_info(playlist_tracks)").all() as any[];
  const colNames = new Set(columns.map((c: any) => c.name));
  if (!colNames.has("view_count")) {
    db.exec("ALTER TABLE playlist_tracks ADD COLUMN view_count INTEGER DEFAULT 0");
  }
  if (!colNames.has("like_count")) {
    db.exec("ALTER TABLE playlist_tracks ADD COLUMN like_count INTEGER DEFAULT 0");
  }

  // Миграция: добавить current_track в player_state
  const psCols = db.prepare("PRAGMA table_info(player_state)").all() as any[];
  const psColNames = new Set(psCols.map((c: any) => c.name));
  if (!psColNames.has("current_track")) {
    db.exec("ALTER TABLE player_state ADD COLUMN current_track TEXT");
  }

  // Миграция: добавить user_id в playlists
  const playlistCols = db.prepare("PRAGMA table_info(playlists)").all() as any[];
  const playlistColNames = new Set(playlistCols.map((c: any) => c.name));
  if (!playlistColNames.has("user_id")) {
    db.exec("ALTER TABLE playlists ADD COLUMN user_id INTEGER REFERENCES users(id)");
  }
}

export function getDb(): Database.Database {
  if (!db) throw new Error("Database not initialized. Call initDb() first.");
  return db;
}
