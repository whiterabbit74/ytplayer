# Микротаски: бэкенд для iPhone‑клиента

Дата: 2026-03-11

## P0
- [x] Добавить поддержку Bearer‑токенов в `requireAuth` (совместимо с cookie).
- [x] Ввести `/api/v1` маршруты и подключить существующие роутеры.
- [x] Добавить таблицу `refresh_tokens` и индексы.
- [x] Реализовать mobile‑auth endpoints: login/refresh/logout (token‑based).
- [x] Обновить конфиги секретов/TTL для access и refresh.

## P1
- [x] Единый формат ошибок для `/api/v1/auth/*`.
- [x] Документировать mobile‑auth контракт в README.
