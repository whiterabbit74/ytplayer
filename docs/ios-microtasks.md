# Микротаски: iOS приложение MusicPlay

## P0
- [x] Создать Xcode‑проект (SwiftUI, iOS 26, iPhone 16 Pro).
- [x] Настроить пакетный слой API (base URL, JSON decoder, ошибки).
- [x] Добавить Keychain storage для access/refresh токенов.
- [x] Реализовать `/api/v1/auth/login` + `/refresh` + `/logout`.
- [x] Реализовать экран логина.
- [x] Реализовать экран поиска (input + suggestions + results).
- [x] Реализовать API `/api/v1/search` (типизированные модели).
- [x] Реализовать AVPlayer интеграцию с `/api/v1/stream/:videoId`.
- [x] Реализовать mini‑player + full‑player.
- [x] Реализовать sync с `/api/v1/player/state`.

## P1
- [x] Реализовать плейлисты (list/create/delete).
- [x] Реализовать треки плейлиста (list/add/remove/reorder).
- [x] Реализовать избранное (list/add/remove, optimistic).
- [x] Реализовать очередь (add/remove/reorder, UI).

## P2
- [x] Полировка UI в стиле Apple Music (HIG, typography, color, spacing).
- [x] Оптимизация списков (LazyVStack, image caching).
- [x] Улучшить стабильность фонового аудио (Audio Session, interruptions).
