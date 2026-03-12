# MusicPlay

Персональный proxy веб-плеер для YouTube. Нет необходимости в vpn.

## Скриншоты

| Плеер | Переключатель языка | Логин |
|:---:|:---:|:---:|
| ![Плеер](docs/screenshots/main-player-ru.png) | ![Переключатель языка](docs/screenshots/main-lang-switcher.png) | ![Логин](docs/screenshots/login-ru.png) |

## Возможности

- Поиск треков через YouTube Data API
- Потоковое воспроизведение аудио (yt-dlp + ffmpeg)
- Плейлисты — создание, редактирование, управление треками
- Очередь воспроизведения с режимами повтора (off / all / one)
- Авторизация по email/паролю (без регистрации, только whitelist)
- Синхронизация состояния плеера между устройствами (очередь, позиция, плейлисты)
- PWA — установка на телефон, фоновое воспроизведение через Media Session API
- Мультиязычность — русский, казахский, английский (автоопределение + ручной выбор)
- Адаптивный интерфейс: полноценный десктоп и мобильная версия с мини-плеером

## Стек

**Клиент:** React 19, TypeScript, Tailwind CSS 4, Zustand, Radix UI, Vite 7, Lucide Icons

**Сервер:** Node.js, Express 5, TypeScript, better-sqlite3, bcryptjs, JWT, yt-dlp

**Инфраструктура:** Docker (multi-stage), Caddy (reverse proxy + auto-HTTPS), GitHub Actions CI/CD, GHCR

## Структура проекта

```
musicplay/
├── client/           # React SPA
│   └── src/
│       ├── components/   # UI-компоненты (Player, SearchBar, Queue, ...)
│       ├── contexts/     # AuthContext
│       ├── i18n/         # Мультиязычность (RU, KK, EN)
│       ├── hooks/        # useAudio, useMediaSession, usePlayerSync
│       ├── lib/          # API-клиенты (api, auth-api, player-state-api, playlist-api)
│       └── stores/       # Zustand store (player)
├── server/           # Express API
│   └── src/
│       ├── routes/       # auth, playlists, player-state, search, stream
│       ├── middleware/    # auth (JWT)
│       ├── db.ts         # SQLite schema + миграции
│       └── create-user.ts # CLI для создания пользователей
├── deploy/           # Docker Compose + Caddyfile
├── design/           # Макеты (Pencil.dev)
└── docs/plans/       # Проектные документы
```

## Установка и запуск

### Требования

- Node.js 22+
- yt-dlp (установлен в PATH)
- ffmpeg
- YouTube Data API ключ

### 1. Клонирование и установка зависимостей

```bash
git clone <repo-url> musicplay
cd musicplay
npm install
cd client && npm install && cd ..
cd server && npm install && cd ..
```

### 2. Настройка окружения

```bash
cp server/.env.example server/.env
```

Заполни `server/.env`:

```
YOUTUBE_API_KEY=<твой YouTube Data API ключ>
JWT_SECRET=<случайная строка для подписи JWT>
JWT_ACCESS_SECRET=<секрет для access-токенов (если не задан, используется JWT_SECRET)>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL_DAYS=30
```

### 3. Создание пользователя

Регистрации нет — пользователей создаёт администратор через CLI:

```bash
cd server
npm run create-user -- --email user@example.com --password mypassword
```

### 4. Запуск в режиме разработки

Из корня проекта:

```bash
npm run dev
```

Это запустит одновременно:
- **Сервер** на `http://localhost:3001` (tsx watch, авторестарт при изменениях)
- **Клиент** на `http://localhost:5173` (Vite dev server, проксирует `/api` на сервер)

## API

Все эндпоинты (кроме авторизации) требуют JWT cookie.

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/auth/login` | Вход (email + password) |
| POST | `/api/auth/logout` | Выход |
| GET | `/api/auth/me` | Текущий пользователь |
| GET | `/api/search?q=...` | Поиск треков на YouTube |
| GET | `/api/stream/:videoId` | Аудиопоток трека |
| GET | `/api/player/state` | Состояние плеера |
| PUT | `/api/player/state` | Сохранить состояние плеера |
| GET | `/api/playlists` | Список плейлистов |
| POST | `/api/playlists` | Создать плейлист |
| PUT | `/api/playlists/:id` | Переименовать плейлист |
| DELETE | `/api/playlists/:id` | Удалить плейлист |
| GET | `/api/playlists/:id/tracks` | Треки плейлиста |
| POST | `/api/playlists/:id/tracks` | Добавить трек |
| DELETE | `/api/playlists/:id/tracks/:trackId` | Удалить трек |
| PUT | `/api/playlists/:id/tracks/reorder` | Изменить порядок треков |

### Mobile API (Bearer tokens)

`/api/v1/*` — версия API для мобильных клиентов. Авторизация через `Authorization: Bearer <accessToken>`.

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/v1/auth/login` | Вход → `accessToken` + `refreshToken` |
| POST | `/api/v1/auth/refresh` | Обновление access-токена |
| POST | `/api/v1/auth/logout` | Инвалидация refresh-токена |

## Деплой

Проект деплоится автоматически при пуше в `main`.

### Пайплайн (GitHub Actions)

1. Сборка Docker-образа (multi-stage: client build, server build, production)
2. Пуш в GHCR (`ghcr.io/voenniy/ytplayer:latest`)
3. SSH на сервер → `docker compose pull && docker compose up -d`

### Ручной деплой

На сервере:

```bash
cd ~/musicplay
cp deploy/.env.example .env   # заполнить переменные
cp deploy/docker-compose.yml .
cp deploy/Caddyfile .
docker compose up -d
```

### Docker Compose

- **app** — Node.js сервер с клиентской статикой, SQLite в volume `db-data`
- **caddy** — Reverse proxy с автоматическим HTTPS (Let's Encrypt)

## Синхронизация между устройствами

Состояние плеера (очередь, текущий трек, позиция, режим повтора) сохраняется на сервер:
- Каждые 30 секунд
- При паузе, смене трека
- При сворачивании вкладки (`visibilitychange`)
- При закрытии страницы (`beforeunload`)

При входе на другом устройстве состояние загружается с сервера.

## Тестирование

```bash
npm test              # все тесты
npm run test:server   # только сервер
npm run test:client   # только клиент
```

## Лицензия

Приватный проект. Не предназначен для публичного использования.
