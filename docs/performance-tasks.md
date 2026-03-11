# Performance задачи по итогам аудита

Дата: 2026-03-11
Основание: `/Users/q/Work/NOTMY/ytplayer/docs/performance-audit.md`

## P0 — немедленно (высокий эффект, низкий риск)

1. Дедупликация `loadPlaylists()`
- Цель: убрать множественные сетевые вызовы при рендере списков.
- Где:
  - `client/src/stores/playlists.ts`
  - `client/src/components/TrackList.tsx`
  - `client/src/components/Player.tsx`
  - `client/src/components/PlaylistList.tsx`
  - `client/src/components/MiniPlayer.tsx`
  - `client/src/components/FullscreenPlayer.tsx`
- Шаги:
  - В `playlists` store добавить `isLoading`, `loadedAt`, `inFlight`.
  - В `loadPlaylists()`:
    - если есть активный `inFlight` — вернуть его.
    - если `loadedAt` < 2–5 мин — не запрашивать заново.
  - Вызов `loadPlaylists()` перенести в один верхнеуровневый компонент после логина.
  - Удалить локальные `useEffect(() => loadPlaylists())` в местах, где это безопасно.
- Готово когда:
  - Один запрос на плейлисты при старте сессии.
  - Нет всплесков сетевых запросов при рендере списков.

2. O(1) проверка очереди в `TrackList`
- Цель: убрать O(n^2) при рендере больших списков.
- Где: `client/src/components/TrackList.tsx`
- Шаги:
  - Создать `const queueIndexById = useMemo(() => new Map(queue.map((t, i) => [t.id, i])), [queue])`.
  - Заменить `queue.findIndex` на `queueIndexById.get(track.id)`.
- Готово когда:
  - Перебор списка не вызывает поиск по очереди для каждого трека.

3. Троттлинг UI‑обновлений `currentTime`
- Цель: снизить ререндеры всего дерева.
- Где: `client/src/hooks/useAudio.ts`
- Шаги:
  - В `onTimeUpdate` обновлять `currentTime` не чаще 200–500 мс.
  - Сохранение `musicplay-position` оставить 1–2 секунды.
- Готово когда:
  - Ререндеры по `currentTime` идут <= 5 раз в секунду.

4. Lazy‑loading изображений в списках
- Цель: уменьшить нагрузку на сеть и main thread.
- Где:
  - `client/src/components/TrackList.tsx`
  - `client/src/components/PlaylistDetail.tsx`
  - `client/src/components/FavoritesList.tsx` (если есть отдельные изображения)
- Шаги:
  - Добавить `loading="lazy"` и `decoding="async"` на `<img>` в списках.
- Готово когда:
  - Изображения вне viewport не грузятся сразу.

## P1 — средний срок (существенный эффект)

5. Виртуализация длинных списков
- Цель: ускорить рендер списков и скролл.
- Где:
  - `client/src/components/TrackList.tsx`
  - `client/src/components/PlaylistDetail.tsx`
  - `client/src/components/Queue.tsx` (если список большой)
- Шаги:
  - Выбрать библиотеку: `react-window` или `@tanstack/react-virtual`.
  - Вынести строки списка в отдельный компонент‑row.
  - Заменить `map` на виртуализированный рендер.
- Готово когда:
  - Списки > 200 элементов не приводят к фризам при скролле.

6. Оптимизация буфера стрима без `Buffer.concat`
- Цель: снизить CPU и аллокации при `cache hit`.
- Где: `server/src/routes/stream.ts`
- Шаги:
  - Перейти на структуру буфера без `Buffer.concat` на каждый `slice`.
  - Вариант: хранить единый `Buffer` с grow‑стратегией или ring‑buffer.
- Готово когда:
  - На `cache hit` отсутствуют большие аллокации.

7. Индексы SQLite для частых запросов
- Цель: ускорить операции по `user_id` и `playlist_id`.
- Где: `server/src/db.ts`
- Шаги:
  - Добавить индексы:
    - `CREATE INDEX IF NOT EXISTS idx_playlists_user_id ON playlists(user_id);`
    - `CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_pos ON playlist_tracks(playlist_id, position);`
    - `CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);`
- Готово когда:
  - `EXPLAIN QUERY PLAN` показывает использование индексов.

8. Дебаунс и батчинг `usePlayerSync`
- Цель: сократить сетевые запросы.
- Где: `client/src/hooks/usePlayerSync.ts`
- Шаги:
  - Добавить `debounced` синхронизацию (5–10 секунд).
  - Исключить синхронизацию при малых изменениях.
  - На `beforeunload` делать принудительный `flush`.
- Готово когда:
  - Частота сетевых запросов < 1 раз в 10 сек при активном использовании.

## P2 — долгий срок (архитектурные улучшения)

9. Выделение аудио‑состояния в отдельный store
- Цель: изолировать ререндеры.
- Где:
  - `client/src/hooks/useAudio.ts`
  - `client/src/components/Player.tsx`
  - `client/src/components/MiniPlayer.tsx`
  - `client/src/components/FullscreenPlayer.tsx`
- Шаги:
  - Вынести `currentTime`, `duration`, `isPlaying`, `volume` в отдельный Zustand‑store.
  - Подписывать только компоненты плеера.
- Готово когда:
  - Ререндеры не затрагивают `App` при обновлении времени.

10. Кеш подсказок поиска + отмена запросов
- Цель: уменьшить нагрузку и гонки ответов.
- Где:
  - `client/src/components/SearchBar.tsx`
  - `client/src/lib/api.ts` (если есть fetch обертки)
- Шаги:
  - Добавить `AbortController` для отмены прошлых запросов.
  - Вести `Map<string, {ts, data}>` с TTL 1–5 минут.
- Готово когда:
  - При быстром вводе нет гонок и лишних запросов.

11. Пагинация для избранного/плейлистов
- Цель: снизить нагрузку при росте данных.
- Где:
  - `server/src/routes/playlists.ts`
  - `server/src/routes/favorites.ts`
  - `client/src/lib/playlist-api.ts`, `client/src/lib/favorites-api.ts` (если есть)
- Шаги:
  - Добавить `limit/offset` в API.
  - На клиенте — "Load more" или infinite scroll.
- Готово когда:
  - При 1000+ треков UI остается отзывчивым.

## Метрики для проверки эффекта

- Клиент:
  - INP < 200ms на основных экранах.
  - Скролл списков без jank при 200–500 элементах.
- Сервер:
  - `/api/stream` без CPU spikes при cache hit.
  - `/api/playlists` и `/api/favorites` ускорены индексами.

