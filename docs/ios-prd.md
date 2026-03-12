# PRD: MusicPlay iOS (iOS 26, iPhone 16 Pro)

## 1. Executive Summary

**Problem Statement**: Текущий MusicPlay — веб‑клиент; на iPhone нужен нативный плеер уровня Apple Music с устойчивым фоновым воспроизведением и быстрым доступом к библиотеке, строго через `/api/v1` Bearer‑auth.

**Proposed Solution**: Нативное iOS‑приложение на SwiftUI для iOS 26, интегрированное с существующим backend `/api/v1`, с потоковым аудио через `/api/v1/stream` и полным функционалом поиска/плейлистов/очереди/избранного.

**Success Criteria**:
- Логин через `/api/v1/auth/login` с получением `accessToken` и `refreshToken` работает стабильно (>= 99% успешных входов при корректных данных).
- Время старта воспроизведения трека ≤ 1.5 секунды при стабильной сети.
- Фоновое воспроизведение работает после сворачивания и на экране блокировки.
- Поиск возвращает первые результаты ≤ 800 мс при типовом запросе.
- Приложение не падает при 2‑часовом непрерывном воспроизведении (0 крашей, 0 утечек памяти).

## 2. User Experience & Functionality

**User Personas**:
- Основной пользователь: владелец iPhone 16 Pro, слушает музыку ежедневно, предпочитает Apple Music‑подобный UX.

**User Stories + Acceptance Criteria**:

1) **Login**
- Story: Как пользователь, я хочу войти по email/паролю, чтобы получить доступ к своей библиотеке.
- AC:
  - Используется только `/api/v1/auth/login` (Bearer tokens).
  - `accessToken` хранится в Keychain, refresh‑ротация работает.
  - Ошибки логина показываются с понятным текстом.

2) **Search**
- Story: Как пользователь, я хочу искать треки и быстро видеть результаты.
- AC:
  - Инпут с подсказками (debounce 250–400 мс).
  - Результаты отображаются списком с мини‑артворком, названием, артистом, длительностью.
  - Нажатие на результат сразу запускает проигрывание.

3) **Playback**
- Story: Как пользователь, я хочу слушать треки в фоне и управлять ими с экрана блокировки.
- AC:
  - AVPlayer играет поток `/api/v1/stream/:videoId`.
  - Работают play/pause/next/prev из Control Center/Lock Screen.
  - Приложение сохраняет позицию трека и синхронизирует её с сервером.

4) **Queue**
- Story: Как пользователь, я хочу управлять очередью треков.
- AC:
  - Добавление/удаление треков в очередь.
  - Перемещение треков в очереди (drag‑and‑drop).
  - Синхронизация очереди с `/api/v1/player/state`.

5) **Playlists**
- Story: Как пользователь, я хочу создавать плейлисты и управлять треками.
- AC:
  - Создание/удаление плейлистов.
  - Добавление/удаление треков.
  - Перестановка треков.

6) **Favorites**
- Story: Как пользователь, я хочу быстро отмечать избранные треки.
- AC:
  - Добавление/удаление в избранное.
  - Список избранного обновляется мгновенно (optimistic UI).

**Non‑Goals**:
- Публичный релиз в App Store.
- Социальные функции/шаринг.
- Оффлайн‑скачивание треков.

## 3. AI System Requirements
Не применяется.

## 4. Technical Specifications

**Architecture Overview**:
- iOS: SwiftUI + AVFoundation + Combine/async‑await.
- Data layer: API client (Bearer auth) + Keychain storage + локальный кеш (in‑memory, опционально файл).
- Playback: AVPlayer + Now Playing + Remote Commands.

**Integration Points**:
- `/api/v1/auth/login` → access/refresh tokens.
- `/api/v1/auth/refresh` → обновление access.
- `/api/v1/auth/logout` → отзыв refresh.
- `/api/v1/search?q=` → поиск.
- `/api/v1/stream/:videoId` → аудио поток.
- `/api/v1/playlists` и `/api/v1/playlists/:id/tracks`.
- `/api/v1/favorites`.
- `/api/v1/player/state`.

**Security & Privacy**:
- Токены только в Keychain.
- HTTPS обязательный.
- Логи без персональных данных.

## 5. Risks & Roadmap

**Phased Rollout**:
- v1.0: Полный функционал, но только для 1 устройства.
- v1.1: Улучшение перфоманса и стабильности.

**Technical Risks**:
- Стриминг YouTube аудио на iOS (качество сети, стабильность длительных сессий).
- Ограничения Apple по фоновой активности.
- Токены могут истекать в фоне — нужен auto‑refresh.
