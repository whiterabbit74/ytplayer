
import { initDb, getDb } from "./db";
import { searchYouTube } from "./services/youtube";
import dotenv from "dotenv";

dotenv.config();

/**
 * UNIVERSAL BULK IMPORT SCRIPT
 * 
 * Instructions:
 * 1. Set the playlistTitle and targetEmail
 * 2. Update the songs array
 * 3. Run: npx tsx src/bulk-import.ts
 */

const targetEmail = "dimazru@gmail.com";
const playlistTitle = "Французский вайб"; // Change this for each new import

const songs = [
  // Paste your songs here
  "Ego - Willy William",
  "Je veux tes yeux - Angèle",
  "Papaoutai - Stromae",
  "Tous Les Mêmes - Stromae",
  "Tourner DansAntoine - Indila",
  "Alors on danse - Stromae",
  "Balance ton quoi - Angèle",
  "Djadja - Aya Nakamura",
  "Le temps est bon - Bon Entendeur, Isabelle Pierre",
  "Salop(e) - Therapie TAXI",
  "Soleil - Roméo Elvis",
  "Formidable - Stromae",
  "Avenir - Louane",
  "Quelqu'un m'a dit - Carla Bruni",
  "La Thune - Angèle",
  "J'écris - Yseult",
  "Voyage Voyage - Desireless",
  "Joe le taxi - Vanessa Paradis",
  "Mini World - Indila",
  "Sympathique - Pink Martini"
];

async function run() {
  initDb();
  const db = getDb();
  
  const user = db.prepare("SELECT id FROM users WHERE email = ?").get(targetEmail) as { id: number } | undefined;

  if (!user) {
    console.error(`User ${targetEmail} not found`);
    process.exit(1);
  }

  // Get or Create playlist
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
    console.log(`[${i + 1}/${songs.length}] Processing: ${query}...`);
    
    try {
      const searchResult = await searchYouTube(query);
      const track = searchResult.tracks[0];
      
      if (track) {
        const existing = db.prepare("SELECT id FROM playlist_tracks WHERE playlist_id = ? AND video_id = ?").get(playlistId, track.id);
        
        if (existing) {
          console.log(`  Already exists: ${track.title}`);
        } else {
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
        }
      } else {
        console.warn(`  No results found on YouTube for: ${query}`);
      }
    } catch (err) {
      console.error(`  Error processing track ${query}:`, err);
    }

    if (i < songs.length - 1) {
      // Mandatory random delay 1-10 seconds
      const waitTime = Math.floor(Math.random() * 9000) + 1000;
      console.log(`  Waiting ${waitTime / 1000} seconds before next request...`);
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }
  }

  console.log("\nAll tracks processed successfully!");
}

run().catch(console.error);
