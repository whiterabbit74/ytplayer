
import { initDb, getDb } from "./db";
import { searchYouTube } from "./services/youtube";
import dotenv from "dotenv";

dotenv.config();

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

async function run() {
  initDb();
  const db = getDb();
  const email = "dimazru@gmail.com";
  const user = db.prepare("SELECT id FROM users WHERE email = ?").get(email) as { id: number } | undefined;

  if (!user) {
    console.error(`User ${email} not found`);
    process.exit(1);
  }

  const playlistTitle = "Электроника и Дэнс";
  const existingPlaylist = db.prepare("SELECT id FROM playlists WHERE name = ? AND user_id = ?").get(playlistTitle, user.id) as { id: number } | undefined;
  
  let playlistId: number;
  if (existingPlaylist) {
    playlistId = existingPlaylist.id;
    console.log(`Using existing playlist: ${playlistTitle} (id: ${playlistId})`);
  } else {
    const result = db.prepare("INSERT INTO playlists (name, user_id) VALUES (?, ?)").run(playlistTitle, user.id);
    playlistId = result.lastInsertRowid as number;
    console.log(`Created playlist: ${playlistTitle} (id: ${playlistId})`);
  }

  for (let i = 0; i < songs.length; i++) {
    const query = songs[i];
    console.log(`[${i + 1}/${songs.length}] Searching for: ${query}...`);
    
    try {
      const searchResult = await searchYouTube(query);
      const track = searchResult.tracks[0];
      
      if (track) {
        const maxPos = db.prepare("SELECT MAX(position) as max FROM playlist_tracks WHERE playlist_id = ?").get(playlistId) as { max: number } | undefined;
        const position = (maxPos?.max ?? -1) + 1;

        db.prepare(
          "INSERT INTO playlist_tracks (playlist_id, video_id, title, artist, thumbnail, duration, view_count, like_count, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        ).run(
          playlistId,
          track.id,
          track.title,
          track.artist,
          track.thumbnail,
          track.duration,
          track.viewCount,
          track.likeCount,
          position
        );
        console.log(`  Added: ${track.title} by ${track.artist}`);
      } else {
        console.warn(`  No results found for: ${query}`);
      }
    } catch (err) {
      console.error(`  Error searching for ${query}:`, err);
    }

    if (i < songs.length - 1) {
      const waitTime = Math.floor(Math.random() * 8000) + 1000;
      console.log(`  Waiting ${waitTime / 1000} seconds...`);
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }
  }

  console.log("Done!");
}

run().catch(console.error);
