import type { Translations } from "../types";

const kk: Translations = {
  // Жалпы
  "common.loading": "Жүктелуде...",

  // Авторизация
  "auth.invalidCredentials": "Қате email немесе құпия сөз",
  "auth.password": "Құпия сөз",
  "auth.signingIn": "Кіру...",
  "auth.signIn": "Кіру",
  "auth.logout": "Шығу",

  // Іздеу
  "search.placeholder": "YouTube сілтемесін қойыңыз немесе іздеңіз...",
  "search.loadMore": "Тағы нәтижелер",

  // Ойнатқыш
  "player.title": "Ойнатқыш",
  "player.nowPlaying": "Қазір ойнатылуда",

  // Кезек
  "queue.addToQueue": "Кезекке қосу",
  "queue.removeFromQueue": "Кезектен алып тастау",
  "queue.title": "Кезек ({{count}})",
  "queue.empty": "Кезек бос",

  // Ойнату тізімдері
  "playlist.addToPlaylist": "Ойнату тізіміне",
  "playlist.createPrompt": "Ойнату тізімінің атауы:",
  "playlist.createNew": "Жаңасын жасау",
  "playlist.newPlaceholder": "Жаңа ойнату тізімі...",
  "playlist.emptyList": "Ойнату тізімдері жоқ",
  "playlist.title": "Ойнату тізімі",
  "playlist.empty": "Ойнату тізімі бос",
  "playlist.playAll": "Барлығын ойнату",
  "playlist.tracks_one": "{{count}} трек",
  "playlist.tracks_few": "{{count}} трек",
  "playlist.tracks_many": "{{count}} трек",

  // Сұрыптау
  "sort.duration": "Ұзақтығы",
  "sort.views": "Көрілімдер",
  "sort.likes": "Лайктар",

  // Навигация
  "nav.search": "Іздеу",
  "nav.playlists": "Ойнату тізімдері",
  "nav.queue": "Кезек",
  "nav.favorites": "Таңдаулылар",

  // Таңдаулылар
  "favorites.added": "Таңдаулыларға қосылды",
  "favorites.removed": "Таңдаулылардан өшірілді",
  "favorites.empty": "Таңдаулыларда әзірге ештеңе жоқ",

  // Параметрлер
  "settings.title": "Параметрлер",
  "settings.account": "Аккаунт",
  "settings.loggedInAs": "Сіз келесі ретінде кірдіңіз:",
} as const;

export default kk;
