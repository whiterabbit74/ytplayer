import Database from "better-sqlite3";
import dotenv from "dotenv";
import { resolve } from "path";

dotenv.config({ path: resolve(__dirname, "../.env") });

const db = new Database(process.env.DB_PATH || "./musicplay.db");
const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY;

if (!YOUTUBE_API_KEY) {
  console.error("YOUTUBE_API_KEY is not set in .env");
  process.exit(1);
}

const TARGET_EMAIL = "dimazru@gmail.com";

const songs = [
  "Сплин - Передайте это Гарри Поттеру...",
  "Fleetwood Mac - The Chain (2004 Remaster)",
  "Trap Remix Guys - Harry Potter - Trap Remix",
  "T3NZU - Balenciaga",
  "Timbaland, Nelly Furtado, SoShy - Morning After Dark",
  "Minelli - Rampampam",
  "BL3SS, CamrinWatsin, bbyclose - Kisses (feat. bbyclose)",
  "MBNN, Rowald Steyn - ilomilo",
  "Alex Warren - Ordinary",
  "Guano Apes - Lords of the Boards",
  "Артем Пора Домой, MVGMA, Маша и Медведи - ЗЕМЛЯ",
  "Eminem, 50 Cent, Ca$his, Lloyd Banks - You Don't Know",
  "SLAVA MARLOW - • ХОТЕЛ ТЕБЕ СКАЗАТЬ...",
  "Stromae - L'enfer",
  "Iliona - Si tu m'aimes demain",
  "Therapie TAXI, Roméo Elvis - Hit Sale",
  "Vanille - Suivre le soleil",
  "БУТРА - Давай сбежим (Искорки)",
  "Анет Сай - СЛЁЗЫ - Из т/ш Пацанки"
];

async function searchAndAdd() {
  const user = db.prepare("SELECT id FROM users WHERE email = ?").get(TARGET_EMAIL) as { id: number } | undefined;
  if (!user) {
    console.error(`User ${TARGET_EMAIL} not found`);
    return;
  }

  console.log(`Working for user ID: ${user.id}`);

  for (const songQuery of songs) {
    try {
      console.log(`Searching for: ${songQuery}`);
      
      const searchUrl = new URL("https://www.googleapis.com/youtube/v3/search");
      searchUrl.searchParams.set("part", "snippet");
      searchUrl.searchParams.set("q", songQuery);
      searchUrl.searchParams.set("type", "video");
      searchUrl.searchParams.set("maxResults", "1");
      searchUrl.searchParams.set("key", YOUTUBE_API_KEY!);

      const searchRes = await fetch(searchUrl.toString());
      const searchData = await searchRes.json();

      if (!searchData.items || searchData.items.length === 0) {
        console.warn(`No results for ${songQuery}`);
        continue;
      }

      const videoId = searchData.items[0].id.videoId;
      const snippet = searchData.items[0].snippet;

      // Get duration
      const videoUrl = new URL("https://www.googleapis.com/youtube/v3/videos");
      videoUrl.searchParams.set("part", "contentDetails");
      videoUrl.searchParams.set("id", videoId);
      videoUrl.searchParams.set("key", YOUTUBE_API_KEY!);

      const videoRes = await fetch(videoUrl.toString());
      const videoData = await videoRes.json();
      const durationIso = videoData.items[0]?.contentDetails?.duration || "PT0S";
      const duration = parseDuration(durationIso);

      const title = snippet.title;
      const artist = snippet.channelTitle;
      const thumbnail = `/api/thumb/${videoId}`;

      // Add to favorites
      const existing = db.prepare("SELECT id FROM favorites WHERE user_id = ? AND video_id = ?").get(user.id, videoId);
      if (existing) {
        console.log(`Already in favorites: ${title}`);
      } else {
        const lastPos = db.prepare("SELECT MAX(position) as max FROM favorites WHERE user_id = ?").get(user.id) as { max: number | null };
        const position = (lastPos.max || 0) + 1;

        db.prepare(
          "INSERT INTO favorites (user_id, video_id, title, artist, thumbnail, duration, position) VALUES (?, ?, ?, ?, ?, ?, ?)"
        ).run(user.id, videoId, title, artist, thumbnail, duration, position);
        
        console.log(`Added to favorites: ${title}`);
      }

      // Random sleep 2-10s
      const delay = Math.floor(Math.random() * 8000) + 2000;
      console.log(`Sleeping for ${delay}ms...`);
      await new Promise(r => setTimeout(r, delay));

    } catch (err) {
      console.error(`Error processing ${songQuery}:`, err);
    }
  }

  console.log("Done!");
}

function parseDuration(iso8601: string): number {
  const match = iso8601.match(/P(?:(\d+)W)?(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return 0;
  const weeks = parseInt(match[1] || "0");
  const days = parseInt(match[2] || "0");
  const hours = parseInt(match[3] || "0");
  const minutes = parseInt(match[4] || "0");
  const seconds = parseInt(match[5] || "0");
  return weeks * 604800 + days * 86400 + hours * 3600 + minutes * 60 + seconds;
}

searchAndAdd();
