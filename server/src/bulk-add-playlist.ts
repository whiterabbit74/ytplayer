
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
const PLAYLIST_NAME = "Электроника и Дэнс";

const songs = [
  "Losing It - FISHER",
  "Latch - Disclosure, Sam Smith",
  "Innerbloom - RÜFÜS DU SOL",
  "You & Me (Flume Remix) - Disclosure, Flume",
  "Tarantula - Pendulum",
  "Alone - Alan Walker",
  "No Sleep - Martin Garrix, Bonn",
  "Intoxicated - Martin Solveig, GTA",
  "Redlight - Swedish House Mafia, Sting",
  "Piece Of Your Heart - MEDUZA, Goodboys",
  "In My Mind - Dynoro, Gigi D'Agostino",
  "Roses (Imanbek Remix) - SAINt JHN",
  "The Business - Tiësto",
  "Cola - CamelPhat, Elderbrook",
  "Bangarang - Skrillex, Sirah",
  "Goosebumps - Travis Scott, HVME",
  "Hear Me Now - Alok, Bruno Martini, Zeeba",
  "I Can't Stop - Flux Pavilion",
  "Do It To It - ACRAZE",
  "Heads Will Roll (A-Trak Remix) - Yeah Yeah Yeahs",
  "Core - RL Grime",
  "Turn Down for What - DJ Snake, Lil Jon",
  "Feel So Close - Calvin Harris",
  "Tsunami - DVBBS, Borgeous",
  "Clarity - Zedd, Foxes",
  "Reload - Sebastian Ingrosso, Tommy Trash, John Martin",
  "Tremor - Martin Garrix, Dimitri Vegas & Like Mike",
  "Promises - NERO",
  "Ghosts 'n' Stuff - deadmau5, Rob Swire",
  "Lean On - Major Lazer, DJ Snake"
];

async function searchAndAdd() {
  const user = db.prepare("SELECT id FROM users WHERE email = ?").get(TARGET_EMAIL) as { id: number } | undefined;
  if (!user) {
    console.error(`User ${TARGET_EMAIL} not found`);
    return;
  }

  console.log(`Working for user ID: ${user.id}`);

  // Get or Create playlist
  let playlist = db.prepare("SELECT id FROM playlists WHERE name = ? AND user_id = ?").get(PLAYLIST_NAME, user.id) as { id: number } | undefined;
  if (!playlist) {
    const result = db.prepare("INSERT INTO playlists (name, user_id) VALUES (?, ?)").run(PLAYLIST_NAME, user.id);
    playlist = { id: result.lastInsertRowid as number };
    console.log(`Created playlist: ${PLAYLIST_NAME} (id: ${playlist.id})`);
  } else {
    console.log(`Using existing playlist: ${PLAYLIST_NAME} (id: ${playlist.id})`);
  }

  for (let i = 0; i < songs.length; i++) {
    const songQuery = songs[i];
    try {
      console.log(`[${i+1}/${songs.length}] Searching for: ${songQuery}`);
      
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
      videoUrl.searchParams.set("part", "contentDetails,statistics");
      videoUrl.searchParams.set("id", videoId);
      videoUrl.searchParams.set("key", YOUTUBE_API_KEY!);

      const videoRes = await fetch(videoUrl.toString());
      const videoData = await videoRes.json();
      const videoItem = videoData.items[0];
      
      const durationIso = videoItem?.contentDetails?.duration || "PT0S";
      const duration = parseDuration(durationIso);
      const viewCount = parseInt(videoItem?.statistics?.viewCount || "0");
      const likeCount = parseInt(videoItem?.statistics?.likeCount || "0");

      const title = snippet.title;
      const artist = snippet.channelTitle;
      const thumbnail = `/api/thumb/${videoId}`;

      // Add to playlist
      const existing = db.prepare("SELECT id FROM playlist_tracks WHERE playlist_id = ? AND video_id = ?").get(playlist.id, videoId);
      if (existing) {
        console.log(`Already in playlist: ${title}`);
      } else {
        const lastPos = db.prepare("SELECT MAX(position) as max FROM playlist_tracks WHERE playlist_id = ?").get(playlist.id) as { max: number | null };
        const position = (lastPos.max === null ? -1 : lastPos.max) + 1;

        db.prepare(
          "INSERT INTO playlist_tracks (playlist_id, video_id, title, artist, thumbnail, duration, view_count, like_count, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        ).run(playlist.id, videoId, title, artist, thumbnail, duration, viewCount, likeCount, position);
        
        console.log(`Added to playlist: ${title}`);
      }

      // Random sleep 1-9s
      if (i < songs.length - 1) {
        const delay = Math.floor(Math.random() * 8000) + 1000;
        console.log(`Sleeping for ${delay}ms...`);
        await new Promise(r => setTimeout(r, delay));
      }

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
