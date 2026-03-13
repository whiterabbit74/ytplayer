
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
const playlistTitle = "Классика"; // Change this for each new import

const songs = [
  "Crystallize - Lindsey Stirling",
  "Viva La Vida - David Garrett",
  "Path - Apocalyptica",
  "Palladio - Escala",
  "Carol of the Bells - Lindsey Stirling",
  "Smooth Criminal - 2CELLOS",
  "Destiny - Vanessa-Mae",
  "Sabre Dance - Vanessa-Mae",
  "Explosive - David Garrett",
  "Croatian Rhapsody - Maksim Mrvica",
  "Thunderstruck - 2CELLOS",
  "Experience - Ludovico Einaudi",
  "Time - Hans Zimmer",
  "The Four Seasons, Summer (Presto) - Antonio Vivaldi",
  "Requiem, Dies Irae - W.A. Mozart",
  "Hall of the Mountain King - Apocalyptica",
  "Dance of the Knights - Sergei Prokofiev",
  "Moonlight Sonata (Epic Version) - Hidden Citizens",
  "Kashmir - Escala",
  "Now We Are Free - Hans Zimmer, Lisa Gerrard",
  "Nocturne N20 - Hip Hop Chopin - Roman Dudchyk",
  "Concerto No. 2 in G Minor (Hip-Hop version) - Игорь Корнелюк",
  "Four Seasons - remix - White_Records",
  "Lacrimosa - W. A. Mozart, Lisa Beckley",
  "Sarabande - Escala",
  "Flight of the Bumblebee - Oliver Lewis, Deviations Project",
  "Red Hot (Symphonic Mix) - Ian Wherry, Vanessa-Mae",
  "The Blessed Spirits - Vanessa-Mae",
  "Toccata and Fugue in D Minor - J.S. Bach, Vanessa-Mae",
  "Requiem For A Tower - Escala",
  "In This Shirt - The Irrepressibles",
  "Storm - Vanessa-Mae",
  "Hocus Pocus - Jan Akkerman, Vanessa-Mae",
  "Contradanza - Vanessa-Mae",
  "Vivaldi Storm - 2CELLOS",
  "Beethoven's 5th - David Garrett",
  "He's a Pirate - Hans Zimmer",
  "Shadows - Lindsey Stirling",
  "Nothing Else Matters - Apocalyptica",
  "I'm A-Doun For Lack O' Johnny - Vanessa-Mae"
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
