import { getDb } from "../db";
import { logger } from "../lib/logger";
import type { Track } from "../types";

const log = logger.child({ service: "search-cache" });

const CACHE_TTL_DAYS = 7;
const CACHE_TTL_MS = CACHE_TTL_DAYS * 24 * 60 * 60 * 1000;

export interface CachedSearch {
  tracks: Track[];
  nextPageToken?: string;
}

/**
 * Нормализация поискового запроса для консистентного кеширования
 */
export function normalizeQuery(query: string): string {
  return query.toLowerCase().trim().replace(/\s+/g, " ");
}

/**
 * Получить результаты поиска из кеша
 * Возвращает null если не найдено или устарело
 */
export function getCachedSearch(query: string): CachedSearch | null {
  const db = getDb();
  const normalized = normalizeQuery(query);
  const minCreatedAt = Date.now() - CACHE_TTL_MS;

  const row = db
    .prepare(
      `SELECT video_ids, next_page_token
       FROM search_cache
       WHERE query = ? AND created_at > ?`
    )
    .get(normalized, minCreatedAt) as
    | { video_ids: string; next_page_token: string | null }
    | undefined;

  if (!row) {
    return null;
  }

  log.info({ query: normalized }, "cache hit");

  return {
    tracks: JSON.parse(row.video_ids),
    nextPageToken: row.next_page_token || undefined,
  };
}

/**
 * Сохранить результаты поиска в кеш
 */
export function cacheSearch(
  query: string,
  tracks: Track[],
  nextPageToken?: string
): void {
  const db = getDb();
  const normalized = normalizeQuery(query);

  db.prepare(
    `INSERT OR REPLACE INTO search_cache (query, video_ids, next_page_token, created_at)
     VALUES (?, ?, ?, ?)`
  ).run(normalized, JSON.stringify(tracks), nextPageToken || null, Date.now());

  log.debug({ query: normalized, count: tracks.length }, "cached search results");
}

/**
 * Удалить устаревшие записи из кеша
 */
export function cleanExpiredCache(): void {
  const db = getDb();
  const minCreatedAt = Date.now() - CACHE_TTL_MS;

  const result = db
    .prepare("DELETE FROM search_cache WHERE created_at <= ?")
    .run(minCreatedAt);

  if (result.changes > 0) {
    log.info({ deleted: result.changes }, "cleaned expired cache entries");
  }
}

/**
 * Получить статистику кеша
 */
export function getCacheStats(): { count: number; oldestDays: number | null } {
  const db = getDb();

  const countRow = db
    .prepare("SELECT COUNT(*) as count FROM search_cache")
    .get() as { count: number };

  const oldestRow = db
    .prepare("SELECT MIN(created_at) as oldest FROM search_cache")
    .get() as { oldest: number | null };

  const oldestDays = oldestRow.oldest
    ? Math.floor((Date.now() - oldestRow.oldest) / (24 * 60 * 60 * 1000))
    : null;

  return { count: countRow.count, oldestDays };
}
